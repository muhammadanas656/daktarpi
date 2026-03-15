import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../data/faq_data.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../../presentation/widgets/complaint_dialog.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FAQItem> _filteredList = kFaqList;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredList = kFaqList;
      } else {
        _filteredList =
            kFaqList.where((item) {
              return item.question.toLowerCase().contains(query) ||
                  item.answer.toLowerCase().contains(query) ||
                  item.category.toLowerCase().contains(query);
            }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: "Help Center",
        onBackPressed: () => context.pop(),
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Padding(
            padding: EdgeInsets.all(16.0),
            child: AppTextField(
              controller: _searchController,
              hintText: "Search for help...",
              prefix: Icon(Icons.search, color: Colors.grey),
            ),
          ),

          // --- FAQ LIST ---
          Expanded(
            child:
                _filteredList.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No results found",
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) {
                        final item = _filteredList[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: AppStyles.surfaceCard(
                            context,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(
                                item.question,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: context.colorTextDark,
                                ),
                              ),
                              childrenPadding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              backgroundColor: Colors.transparent,
                              collapsedBackgroundColor: Colors.transparent,
                              iconColor: AppColors.primaryGreen,
                              collapsedIconColor: Colors.grey,
                              children: [
                                Text(
                                  item.answer,
                                  style: TextStyle(
                                    height: 1.5,
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // --- PREMIUM SUPPORT ACTION CARD ---
          Container(
            padding: const EdgeInsets.all(24), // Slightly more breathing room
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: AppStyles.elevatedShadow(context), // Premium depth
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Still need help?",
                    style: AppTextStyles.bodyBold(context).copyWith(
                      color: context.colorTextLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 58, // Professional reachability sizing
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      // PRO FIX: Beautiful brand-colored glow
                      boxShadow: AppStyles.primaryShadow(
                        context,
                        AppColors.primaryGreen,
                        alpha: 0.3,
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder:
                              (ctx) => ComplaintDialog(
                                isSupportMode:
                                    true, // Triggers the Blue Support UI
                                onComplaintSubmitted: () {},
                              ),
                        );
                      },
                      icon: const Icon(Icons.support_agent_rounded, size: 24),
                      label: const Text("Submit Complaint to Support"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors
                                .primaryGreen, // Restored your beautiful Green
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
