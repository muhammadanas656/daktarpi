import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../data/medical_record.dart';
import '../../data/medical_record_repository.dart';

class AddRecordScreen extends StatefulWidget {
  final MedicalRecord? recordToEdit;
  const AddRecordScreen({super.key, this.recordToEdit});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _repository = MedicalRecordRepository();
  final _nameController = TextEditingController();

  String _selectedType = 'Report';
  DateTime _selectedDate = DateTime.now();

  final List<File> _selectedImages = [];
  final List<File> _selectedDocs = [];

  final List<String> _existingImageUrls = [];
  final List<String> _existingDocUrls = [];

  final _picker = ImagePicker();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _recordTypes = [
    {'type': 'Report', 'icon': Icons.analytics_outlined},
    {'type': 'Prescription', 'icon': Icons.medical_services_outlined},
    {'type': 'Invoice', 'icon': Icons.receipt_long_outlined},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.recordToEdit != null) {
      final record = widget.recordToEdit!;
      _nameController.text = record.recordFor;
      _selectedType = record.recordType;
      _selectedDate = record.recordDate;

      for (var url in record.fileUrls) {
        if (_isImage(url)) {
          _existingImageUrls.add(url);
        } else {
          _existingDocUrls.add(url);
        }
      }
    }
  }

  bool _isImage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'heic'].contains(ext);
  }

  String _getCleanFileName(String path) {
    String name = path.split('/').last;
    return name.replaceFirst(RegExp(r'^\d+_'), '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to pick images: $e");
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to capture photo: $e");
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() {
          _selectedDocs.addAll(
            result.paths.map((path) => File(path!)).toList(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to pick files: $e");
      }
    }
  }

  void _showImageOptions() {
    // FIXED: Removed unused 'isDark' variable
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: context.colorTextDark),
                  title: Text(
                    'Take a photo',
                    style: TextStyle(color: context.colorTextDark),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library,
                    color: context.colorTextDark,
                  ),
                  title: Text(
                    'Choose from gallery',
                    style: TextStyle(color: context.colorTextDark),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data:
              isDark
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme.copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primaryGreen,
                    ),
                  ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _uploadRecord() async {
    if (_nameController.text.trim().isEmpty) {
      CustomSnackbar.showError(context, "Please enter who this record is for.");
      return;
    }

    final hasImages =
        _selectedImages.isNotEmpty || _existingImageUrls.isNotEmpty;
    final hasDocs = _selectedDocs.isNotEmpty || _existingDocUrls.isNotEmpty;

    if (!hasImages && !hasDocs) {
      CustomSnackbar.showError(
        context,
        "Please add at least one image or document.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newImageUrls = await _repository.uploadFiles(_selectedImages);
      final newDocUrls = await _repository.uploadFiles(_selectedDocs);

      final allFilePaths = [
        ..._existingImageUrls,
        ..._existingDocUrls,
        ...newImageUrls,
        ...newDocUrls,
      ];

      if (widget.recordToEdit != null) {
        await _repository.updateRecord(
          id: widget.recordToEdit!.id,
          recordFor: _nameController.text.trim(),
          recordType: _selectedType,
          recordDate: _selectedDate,
          fileUrls: allFilePaths,
        );
        if (mounted) {
          CustomSnackbar.showSuccess(context, "Record updated successfully!");
        }
      } else {
        await _repository.addRecord(
          recordFor: _nameController.text.trim(),
          recordType: _selectedType,
          recordDate: _selectedDate,
          fileUrls: allFilePaths,
        );
        if (mounted) {
          CustomSnackbar.showSuccess(context, "Record added successfully!");
        }
      }

      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, "Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFullImage(ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                InteractiveViewer(child: Image(image: imageProvider)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            widget.recordToEdit != null ? "Edit Record" : "Add Records",
            style: AppTextStyles.h2(context),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Center(
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colorBorder),
                  boxShadow: AppStyles.cardShadow(context),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: context.colorTextDark,
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      if (_selectedImages.isNotEmpty ||
                          _existingImageUrls.isNotEmpty)
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ..._existingImageUrls.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final path = entry.value;
                                return _buildThumbnail(
                                  path: path,
                                  onTap:
                                      (url) =>
                                          _showFullImage(NetworkImage(url)),
                                  onDelete:
                                      () => setState(
                                        () =>
                                            _existingImageUrls.removeAt(index),
                                      ),
                                  isNetwork: true,
                                );
                              }),
                              ..._selectedImages.asMap().entries.map((entry) {
                                final index = entry.key;
                                final file = entry.value;
                                return _buildThumbnail(
                                  file: file,
                                  onTap: (_) => _showFullImage(FileImage(file)),
                                  onDelete:
                                      () => setState(
                                        () => _selectedImages.removeAt(index),
                                      ),
                                  isNetwork: false,
                                );
                              }),
                            ],
                          ),
                        ),

                      if (_selectedImages.isNotEmpty ||
                          _existingImageUrls.isNotEmpty)
                        const SizedBox(width: 12),

                      GestureDetector(
                        onTap: _showImageOptions,
                        child: Container(
                          width: 100,
                          height: 120,
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.primaryGreen.withValues(
                                      alpha: 0.15,
                                    )
                                    : const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppColors.primaryGreen.withValues(
                                        alpha: 0.3,
                                      )
                                      : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_a_photo,
                                color: AppColors.primaryGreen,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Add user\nimage",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                AppTextField(
                  controller: _nameController,
                  label: "Record for",
                  hintText: "Enter Name",
                  textCapitalization: TextCapitalization.words,
                  suffixIcon: Icon(
                    Icons.edit,
                    color: context.colorTextLight,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 24),

                _buildLabel("Type of record"),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:
                      _recordTypes.map((item) {
                        final type = item['type'] as String;
                        final icon = item['icon'] as IconData;
                        final isSelected = _selectedType == type;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedType = type);
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? AppColors.primaryGreen
                                          : (isDark
                                              ? Colors.black12
                                              : Colors.transparent),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? AppColors.primaryGreen
                                            : context.colorBorder,
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : context.colorTextLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                type,
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? AppColors.primaryGreen
                                          : context.colorTextLight,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 24),

                _buildLabel("Attachments"),
                const SizedBox(height: 12),

                if (_selectedDocs.isNotEmpty || _existingDocUrls.isNotEmpty)
                  Container(
                    height: 60,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._existingDocUrls.asMap().entries.map(
                          (entry) => _buildDocItem(
                            name: _getCleanFileName(entry.value),
                            onDelete:
                                () => setState(
                                  () => _existingDocUrls.removeAt(entry.key),
                                ),
                          ),
                        ),
                        ..._selectedDocs.asMap().entries.map(
                          (entry) => _buildDocItem(
                            name: entry.value.path.split('/').last,
                            onDelete:
                                () => setState(
                                  () => _selectedDocs.removeAt(entry.key),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                GestureDetector(
                  onTap: _pickFiles,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.primaryGreen.withValues(alpha: 0.5)
                                : AppColors.primaryGreen,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color:
                          isDark
                              ? AppColors.primaryGreen.withValues(alpha: 0.1)
                              : context.colorLightGreenBg.withValues(
                                alpha: 0.3,
                              ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.upload_file, color: AppColors.primaryGreen),
                        SizedBox(width: 8),
                        Text(
                          "Upload Documents (PDF, DOC)",
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildLabel("Record created on"),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.colorBorder),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM, yyyy').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        Icon(
                          Icons.edit,
                          color: context.colorTextLight,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: PrimaryButton(
              label:
                  _isLoading
                      ? "Processing..."
                      : (widget.recordToEdit != null
                          ? "Update record"
                          : "Upload record"),
              onTap: _isLoading ? () {} : _uploadRecord,
              isLoading: _isLoading,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocItem({required String name, required VoidCallback onDelete}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: context.colorTextGrey, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.colorTextDark),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 16, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail({
    String? path,
    File? file,
    required Function(String) onTap,
    required VoidCallback onDelete,
    required bool isNetwork,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () {
                if (isNetwork && path != null) {
                  // Wait handled inside future builder
                } else if (file != null) {
                  onTap('');
                }
              },
              child:
                  isNetwork
                      ? FutureBuilder<String>(
                        future: _repository.getSignedUrl(path!),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              width: 100,
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            );
                          }
                          return GestureDetector(
                            onTap: () => onTap(snapshot.data!),
                            child: Image.network(
                              snapshot.data!,
                              width: 100,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      )
                      : Image.file(
                        file!,
                        width: 100,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: onDelete,
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.colorTextDark,
      ),
    );
  }
}
