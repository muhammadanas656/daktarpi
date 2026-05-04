import 'package:image_cropper/image_cropper.dart';

void main() {
  AndroidUiSettings(cropStyle: CropStyle.circle);
  ImageCropper().cropImage(sourcePath: "abc", cropStyle: CropStyle.circle);
}
