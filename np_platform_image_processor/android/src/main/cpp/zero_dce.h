#pragma once

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT jbyteArray JNICALL
Java_com_nkming_nc_1photos_np_1platform_1image_1processor_processor_ZeroDce_inferNative(
    JNIEnv *env, jobject *thiz, jobject assetManager, jbyteArray image,
    jint width, jint height, jint iteration);

#ifdef __cplusplus
}
#endif
