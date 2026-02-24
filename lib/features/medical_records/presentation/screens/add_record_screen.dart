import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _repository = MedicalRecordRepository();
  final _nameController = TextEditingController();

  String _selectedType = 'Report';
  DateTime _selectedDate = DateTime.now();

  // Split state for UI separation
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

      // Split existing files by type
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
        allowedExtensions: ['pdf', 'doc', 'docx'], // Restrict to docs mostly
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from gallery'),
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: AppTheme.lightTheme.copyWith(
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
    if (!_formKey.currentState!.validate()) return;

    // Check if at least one file/image exists (new or existing)
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
      // 1. Upload NEW Images
      final newImageUrls = await _repository.uploadFiles(_selectedImages);
      // 2. Upload NEW Docs
      final newDocUrls = await _repository.uploadFiles(_selectedDocs);

      // 3. Combine ALL
      final allFilePaths = [
        ..._existingImageUrls,
        ..._existingDocUrls,
        ...newImageUrls,
        ...newDocUrls,
      ];

      // 4. Save
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

      if (mounted) {
        context.pop(true);
      }
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.recordToEdit != null ? "Edit Record" : "Add Records",
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.textDark,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Top Image Selection ---
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
                            // Existing Images
                            ..._existingImageUrls.asMap().entries.map((entry) {
                              final index = entry.key;
                              final path = entry.value;
                              return _buildThumbnail(
                                path: path,
                                onTap:
                                    (url) => _showFullImage(NetworkImage(url)),
                                onDelete:
                                    () => setState(
                                      () => _existingImageUrls.removeAt(index),
                                    ),
                                isNetwork: true,
                              );
                            }),
                            // New Images
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
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(12),
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

              // 2. Record For
              _buildLabel("Record for"),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                decoration: const InputDecoration(
                  hintText: "Enter Name",
                  hintStyle: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.normal,
                  ),
                  suffixIcon: Icon(
                    Icons.edit,
                    color: AppColors.textLight,
                    size: 18,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 24),

              // 3. Type of Record
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
                          // Optional: Trigger specific picker based on type if needed,
                          // checks context. For now, we rely on the manual buttons.
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
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : AppColors.textLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              type,
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? AppColors.primaryGreen
                                        : AppColors.textLight,
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

              // --- 4. Document Selection (Beneath Type) ---
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
                    border: Border.all(color: AppColors.primaryGreen),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.lightGreenBg.withValues(alpha: 0.3),
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

              // 5. Date Picker
              _buildLabel("Record created on"),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderColor),
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
                      const Icon(
                        Icons.edit,
                        color: AppColors.textLight,
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
      bottomNavigationBar: Padding(
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
    );
  }

  // Helper for Documents
  Widget _buildDocItem({required String name, required VoidCallback onDelete}) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: AppColors.textGrey, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
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

  // Helper for Images (Network or File)
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
                  // We need to await generic future here, which is tricky in sync onTap.
                  // Ideally we prefetched signed URL or use a FutureBuilder wrapper.
                  // For this refactor I'll assume we pass the builder widget or use the same FutureBuilder pattern as before.
                } else if (file != null) {
                  onTap(''); // pass empty for file
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
                              child: Center(child: CircularProgressIndicator()),
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
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      ),
    );
  }
}
