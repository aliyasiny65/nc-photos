#include "base_resample.h"
#include "exception.h"
#include "log.h"
#include "stopwatch.h"
#include "tflite_wrapper.h"
#include "util.h"
#include <RenderScriptToolkit.h>
#include <algorithm>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <cassert>
#include <exception>
#include <jni.h>
#include <omp.h>
#include <tensorflow/lite/c/c_api.h>

using namespace plugin;
using namespace renderscript;
using namespace std;
using namespace tflite;

namespace {

constexpr const char *MODEL = "lite-model_mobilenetv2-dm05-coco_dr_1.tflite";
constexpr size_t WIDTH = 513;
constexpr size_t HEIGHT = 513;
constexpr unsigned LABEL_COUNT = 21;

enum struct Label {
  BACKGROUND = 0,
  AEROPLANE,
  BICYCLE,
  BIRD,
  BOAT,
  BOTTLE,
  BUS,
  CAR,
  CAT,
  CHAIR,
  COW,
  DINING_TABLE,
  DOG,
  HORSE,
  MOTORBIKE,
  PERSON,
  POTTED_PLANT,
  SHEEP,
  SOFA,
  TRAIN,
  TV,
};

class DeepLab3 {
public:
  explicit DeepLab3(AAssetManager *const aam);
  DeepLab3(const DeepLab3 &) = delete;
  DeepLab3(DeepLab3 &&) = default;

  std::vector<uint8_t> infer(const uint8_t *image, const size_t width,
                             const size_t height);

private:
  Model model;

  static constexpr const char *TAG = "DeepLap3";
};

class DeepLab3Portrait {
public:
  explicit DeepLab3Portrait(DeepLab3 &&deepLab);

  std::vector<uint8_t> infer(const uint8_t *image, const size_t width,
                             const size_t height, const unsigned radius);

private:
  /**
   * Post-process the segment map.
   *
   * The resulting segment map will:
   * 1. Contain only the most significant label (the one with the most pixel)
   * 2. The label value set to 255
   * 3. The background set to 0
   *
   * @param segmentMap
   */
  void postProcessSegmentMap(std::vector<uint8_t> *segmentMap);

  std::vector<uint8_t> enhance(const uint8_t *image, const size_t width,
                               const size_t height,
                               const std::vector<uint8_t> &segmentMap,
                               const unsigned radius);

  DeepLab3 deepLab;

  static constexpr const char *TAG = "DeepLab3Portrait";
};

} // namespace

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_nkming_nc_1photos_plugin_image_1processor_DeepLab3Portrait_inferNative(
    JNIEnv *env, jobject *thiz, jobject assetManager, jbyteArray image,
    jint width, jint height, jint radius) {
  try {
    initOpenMp();
    auto aam = AAssetManager_fromJava(env, assetManager);
    DeepLab3Portrait model(DeepLab3{aam});
    RaiiContainer<jbyte> cImage(
        [&]() { return env->GetByteArrayElements(image, nullptr); },
        [&](jbyte *obj) {
          env->ReleaseByteArrayElements(image, obj, JNI_ABORT);
        });
    const auto result = model.infer(reinterpret_cast<uint8_t *>(cImage.get()),
                                    width, height, radius);
    auto resultAry = env->NewByteArray(result.size());
    env->SetByteArrayRegion(resultAry, 0, result.size(),
                            reinterpret_cast<const int8_t *>(result.data()));
    return resultAry;
  } catch (const exception &e) {
    throwJavaException(env, e.what());
    return nullptr;
  }
}

namespace {

DeepLab3::DeepLab3(AAssetManager *const aam) : model(Asset(aam, MODEL)) {}

vector<uint8_t> DeepLab3::infer(const uint8_t *image, const size_t width,
                                const size_t height) {
  InterpreterOptions options;
  options.setNumThreads(getNumberOfProcessors());
  Interpreter interpreter(model, options);
  interpreter.allocateTensors();

  LOGI(TAG, "[infer] Convert bitmap to input");
  vector<uint8_t> inputBitmap(WIDTH * HEIGHT * 3);
  base::ResampleImage24(image, width, height, inputBitmap.data(), WIDTH, HEIGHT,
                        base::KernelTypeLanczos3);
  const auto input =
      rgb8ToRgbFloat(inputBitmap.data(), inputBitmap.size(), true);
  auto inputTensor = interpreter.getInputTensor(0);
  assert(TfLiteTensorByteSize(inputTensor) == input.size() * sizeof(float));
  TfLiteTensorCopyFromBuffer(inputTensor, input.data(),
                             input.size() * sizeof(float));

  LOGI(TAG, "[infer] Inferring");
  Stopwatch stopwatch;
  interpreter.invoke();
  LOGI(TAG, "[infer] Elapsed: %.3fs", stopwatch.getMs() / 1000.0f);

  auto outputTensor = interpreter.getOutputTensor(0);
  vector<float> output(WIDTH * HEIGHT * LABEL_COUNT);
  assert(TfLiteTensorByteSize(outputTensor) == output.size() * sizeof(float));
  TfLiteTensorCopyToBuffer(outputTensor, output.data(),
                           output.size() * sizeof(float));
  const auto i1 = (200 * 513 + 260) * LABEL_COUNT;
  return argmax(output.data(), WIDTH, HEIGHT, LABEL_COUNT);
}

DeepLab3Portrait::DeepLab3Portrait(DeepLab3 &&deepLab)
    : deepLab(move(deepLab)) {}

vector<uint8_t> DeepLab3Portrait::infer(const uint8_t *image,
                                        const size_t width, const size_t height,
                                        const unsigned radius) {
  auto segmentMap = deepLab.infer(image, width, height);
  postProcessSegmentMap(&segmentMap);
  return enhance(image, width, height, segmentMap, radius);
}

void DeepLab3Portrait::postProcessSegmentMap(vector<uint8_t> *segmentMap) {
  // keep only the largest segment
  vector<uint8_t> &segmentMapRef = *segmentMap;
  vector<int> count(LABEL_COUNT);
  for (size_t i = 0; i < segmentMapRef.size(); ++i) {
    assert(segmentMapRef[i] < LABEL_COUNT);
    const auto label = std::min<unsigned>(segmentMapRef[i], LABEL_COUNT);
    if (label != static_cast<int>(Label::BACKGROUND)) {
      ++count[label];
    }
  }
  const auto keep = distance(
      count.data(), max_element(count.data(), count.data() + count.size()));
  LOGI(TAG, "[postProcessSegmentMap] Label to keep: %d",
       static_cast<int>(keep));
#pragma omp parallel for
  for (size_t i = 0; i < segmentMapRef.size(); ++i) {
    if (segmentMapRef[i] == keep) {
      segmentMapRef[i] = 0xFF;
    } else {
      segmentMapRef[i] = 0;
    }
  }
}

vector<uint8_t> DeepLab3Portrait::enhance(const uint8_t *image,
                                          const size_t width,
                                          const size_t height,
                                          const vector<uint8_t> &segmentMap,
                                          const unsigned radius) {
  LOGI(TAG, "[enhance] Enhancing image");
  // resize alpha to input size
  vector<uint8_t> alpha(width * height);
  base::ResampleImage<1>(segmentMap.data(), WIDTH, HEIGHT, alpha.data(), width,
                         height, base::KernelTypeLanczos3);
  // smoothen the edge
  vector<uint8_t> alphaFiltered(width * height);
  getToolkitInst().blur(alpha.data(), alphaFiltered.data(), width, height, 1,
                        16);
  alpha.clear();

  // blur input
  auto rgba8 = rgb8ToRgba8(image, width, height);
  vector<uint8_t> blur(width * height * 4);
  getToolkitInst().blur(rgba8.data(), blur.data(), width, height, 4, radius);

  // draw input on top of blurred image, with alpha map
  replaceChannel<4>(rgba8.data(), alphaFiltered.data(), width, height, 3);
  alphaFiltered.clear();
  alphaBlend(rgba8.data(), blur.data(), width, height);
  rgba8.clear();
  return rgba8ToRgb8(blur.data(), width, height);
}

} // namespace
