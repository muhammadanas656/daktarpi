import 'package:image_cropper/image_cropper.dart';

void main() async {
  await ImageCropper().cropImage(
    sourcePath: "abc",
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(cropStyle: CropStyle.circle),
      IOSUiSettings(cropStyle: CropStyle.circle),
    ],
  );
}
