import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:exifdart/exifdart.dart';
import 'package:nc_photos/entity/exif.dart';
import 'package:test/test.dart';

void main() {
  group("Exif", () {
    group("equals", () {
      test("deep equal", () {
        final exif = Exif(<String, dynamic>{
          "ImageWidth": 1024,
        });
        expect(
            exif.equals(
                Exif(<String, dynamic>{
                  "ImageWidth": 1024,
                }),
                isDeep: true),
            true);
      });

      test("deep unequal", () {
        final exif = Exif(<String, dynamic>{
          "ImageWidth": 1024,
        });
        expect(
            exif.equals(
                Exif(<String, dynamic>{
                  "ImageWidth": 2048,
                }),
                isDeep: true),
            false);
      });

      test("shallow equal", () {
        final exif = Exif(<String, dynamic>{
          "ImageWidth": 1024,
        });
        expect(
            exif.equals(
                Exif(<String, dynamic>{
                  "ImageWidth": 1024,
                }),
                isDeep: false),
            true);
      });

      test("shallow equal (different value)", () {
        final exif = Exif(<String, dynamic>{
          "ImageWidth": 1024,
        });
        expect(
            exif.equals(
                Exif(<String, dynamic>{
                  "ImageWidth": 2048,
                }),
                isDeep: false),
            true);
      });

      test("shallow unequal", () {
        final exif = Exif(<String, dynamic>{
          "ImageWidth": 1024,
        });
        expect(
            exif.equals(
                Exif(<String, dynamic>{
                  "ImageWidth": 1024,
                  "ImageHeight": 1024,
                }),
                isDeep: false),
            false);
      });
    });

    group("toJson", () {
      test("int", () {
        final exif = Exif(<String, dynamic>{
          "ImageWidth": 1024,
        });
        expect(exif.toJson(), <String, dynamic>{
          "ImageWidth": 1024,
        });
      });

      test("String", () {
        final exif = Exif(<String, dynamic>{
          "Make": "dummy",
        });
        expect(exif.toJson(), <String, dynamic>{
          "Make": "dummy",
        });
      });

      test("Rational", () {
        final exif = Exif(<String, dynamic>{
          "XResolution": Rational(72, 1),
        });
        expect(exif.toJson(), <String, dynamic>{
          "XResolution": {"n": 72, "d": 1},
        });
      });

      test("List<int>", () {
        final exif = Exif(<String, dynamic>{
          "YCbCrSubSampling": [2, 2],
        });
        expect(exif.toJson(), <String, dynamic>{
          "YCbCrSubSampling": [2, 2],
        });
      });

      test("List<Rational>", () {
        final exif = Exif(<String, dynamic>{
          "GPSLatitude": [Rational(2, 1), Rational(3, 1), Rational(4, 100)],
        });
        expect(exif.toJson(), <String, dynamic>{
          "GPSLatitude": [
            {"n": 2, "d": 1},
            {"n": 3, "d": 1},
            {"n": 4, "d": 100},
          ],
        });
      });

      test("MakerNote", () {
        final exif = Exif(<String, dynamic>{
          "MakerNote": Uint8List.fromList([0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF]),
        });
        expect(exif.toJson(), <String, dynamic>{});
      });

      test("UserComment", () {
        final exif = Exif(<String, dynamic>{
          "UserComment":
              Uint8List.fromList([0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF]),
        });
        expect(exif.toJson(), <String, dynamic>{});
      });
    });

    group("fromJson", () {
      test("int", () {
        final json = <String, dynamic>{
          "ImageWidth": 1024,
        };
        expect(
            Exif.fromJson(json),
            Exif(<String, dynamic>{
              "ImageWidth": 1024,
            }));
      });

      test("String", () {
        final json = <String, dynamic>{
          "Make": "dummy",
        };
        expect(
            Exif.fromJson(json),
            Exif(<String, dynamic>{
              "Make": "dummy",
            }));
      });

      test("Rational", () {
        final json = <String, dynamic>{
          "XResolution": {"numerator": 72, "denominator": 1},
        };
        final Rational exif = Exif.fromJson(json)["XResolution"];
        expect(exif.makeComparable(), _Rational(72, 1));
      });

      test("List<int>", () {
        final json = <String, dynamic>{
          "YCbCrSubSampling": [2, 2],
        };
        expect(
            Exif.fromJson(json),
            Exif(<String, dynamic>{
              "YCbCrSubSampling": [2, 2],
            }));
      });

      test("List<Rational>", () {
        final json = <String, dynamic>{
          "GPSLatitude": [
            {"numerator": 2, "denominator": 1},
            {"numerator": 3, "denominator": 1},
            {"numerator": 4, "denominator": 100},
          ],
        };
        final List<Rational> exif =
            Exif.fromJson(json)["GPSLatitude"].cast<Rational>();
        expect(exif.map((e) => e.makeComparable()).toList(),
            [_Rational(2, 1), _Rational(3, 1), _Rational(4, 100)]);
      });
    });

    group("dateTimeOriginal", () {
      test("problematic value", () {
        final exif = Exif({
          "DateTimeOriginal": " ",
        });
        expect(exif.dateTimeOriginal, null);
      });
      test("empty value", () {
        final exif = Exif({
          "DateTimeOriginal": "",
        });
        expect(exif.dateTimeOriginal, null);
      });
    });
  });
}

extension on Rational {
  _Rational makeComparable() => _Rational.of(this);
}

class _Rational extends Rational with EquatableMixin {
  _Rational(super.numerator, super.denominator);

  factory _Rational.of(Rational r) {
    return _Rational(r.numerator, r.denominator);
  }

  @override
  get props => [
        numerator,
        denominator,
      ];
}
