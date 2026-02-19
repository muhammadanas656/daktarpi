import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';

class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  bool _isLoading = false;
  List<UserIdentity> _identities = [];

  @override
  void initState() {
    super.initState();
    _fetchIdentities();
  }

  void _fetchIdentities() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _identities = user.identities ?? [];
        });
      }
    }
  }

  Future<void> _linkGoogle() async {
    setState(() => _isLoading = true);
    try {
      // Initiate OAuth flow for linking
      // Note: This typically opens a browser. 
      // For native linking, we would need idToken from google_sign_in, but Supabase SDK
      // simplifies this with linkIdentity(OAuthProvider) for web-flow.
      
      await Supabase.instance.client.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: 'io.supabase.daktarpi://login-callback', // Deep link schema
      );
      
      // Note: The app might restart or pause here. 
      // If we return, we refresh.
      if (mounted) {
         _fetchIdentities();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to link Google: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlinkIdentity(UserIdentity identity) async {
    // Safety check: Don't allow unlinking if it's the only method?
    // Supabase might handle this, or we check manually.
    if (_identities.length <= 1 && _identities.first.provider != 'email') {
       // Ideally we check if password triggers exist, but identities list usually includes 'email' if signup was email.
       // Actually, 'email' provider identity exists if they signed up with email.
       // If they only have 'google', unlinking it locks them out?
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Unlink Account?"),
        content: Text("Are you sure you want to unlink ${identity.provider}? You won't be able to sign in with this account anymore."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Unlink", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.unlinkIdentity(identity);
      if (mounted) {
        CustomSnackbar.showSuccess(context, "Account unlinked successfully");
        _fetchIdentities();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to unlink: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProviderTile(String provider, String iconPath, Color color) {
    // Find identity for this provider
    // Supabase providers are 'google', 'email', 'facebook', etc.
    UserIdentity? identity;
    try {
      identity = _identities.firstWhere((id) => id.provider == provider);
    } catch (_) {
      identity = null;
    }
    
    final isLinked = identity != null;
    final isEmail = provider == 'email';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            // Fallback icon if SVG asset missing logic, but let's assume standard icons
            child: Icon(
              provider == 'google' ? Icons.g_mobiledata : Icons.email, // Placeholder for SVG
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider[0].toUpperCase() + provider.substring(1),
                  style: AppTextStyles.bodyBold,
                ),
                if (isLinked)
                  Text(
                    isEmail ? (Supabase.instance.client.auth.currentUser?.email ?? 'Linked') : 'Linked',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (isLinked)
             if (!isEmail) // Don't allow unlinking Email (primary) for now, complex logic
                TextButton(
                  onPressed: () => _unlinkIdentity(identity!),
                  child: const Text("Unlink", style: TextStyle(color: Colors.red)),
                )
             else
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 20),
                )
          else
            TextButton(
              onPressed: provider == 'google' ? _linkGoogle : null, // Only Google supported for linking now
              child: const Text("Link", style: TextStyle(color: AppColors.primaryGreen)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text("Linked Accounts", style: AppTextStyles.h2),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                   const Text(
                     "Manage your signed-in accounts. Linking accounts allows you to sign in with any of them.",
                     style: TextStyle(color: AppColors.textLight, height: 1.5),
                   ),
                   const SizedBox(height: 32),
                   
                   _buildProviderTile('email', 'assets/icons/email.svg', AppColors.primaryGreen),
                   _buildProviderTile('google', 'assets/icons/google.svg', Colors.red),
                   
                   // Add more if supported (Facebook, Apple)
                ],
              ),
            ),
    );
  }
}
