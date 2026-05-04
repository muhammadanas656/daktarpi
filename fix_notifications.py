import re

path = r'c:\skills development\daktarpi\lib\features\notifications\presentation\screens\notifications_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace the block from "return Scaffold(" to the end of SliverAppBar
old_block_start = "    return Scaffold(\n      backgroundColor: Theme.of(context).scaffoldBackgroundColor,\n      body: RefreshIndicator("
old_block_start_crlf = old_block_start.replace('\n', '\r\n')

# Try both line endings
if old_block_start_crlf in content:
    sep = '\r\n'
elif old_block_start in content:
    sep = '\n'
else:
    # Try finding it differently
    print("Could not find exact start block. Searching...")
    idx = content.find("return Scaffold(")
    if idx == -1:
        print("FATAL: Cannot find 'return Scaffold(' in file")
        exit(1)
    # Detect line ending from file
    sep = '\r\n' if '\r\n' in content else '\n'

# Find the start of "return Scaffold("
start_idx = content.find("return Scaffold(")
# Find the end of "SliverAppBar" block - look for "],\n            )," after actions
end_marker = "            ),"
# Find from after SliverAppBar
sliver_app_bar_idx = content.find("SliverAppBar(", start_idx)
# Find the closing of SliverAppBar - it ends with "),\n" 
# Look for the line with just the closing of the SliverAppBar widget
# The pattern after actions is "            ]," then "            ),"
actions_close = content.find("              ]," + sep + "            )," + sep, sliver_app_bar_idx)
if actions_close == -1:
    # Try to find it with single bracket pattern
    actions_close = content.find("            ]," + sep + "            )," + sep, sliver_app_bar_idx)
if actions_close == -1:
    print("Could not find actions close bracket")
    # Let's just find the line numbers
    lines = content.split(sep)
    for i, line in enumerate(lines):
        if i >= 100 and i <= 190:
            print(f"L{i+1}: {repr(line)}")
    exit(1)

# Find the end position (after the ")," that closes SliverAppBar and the empty line)
end_idx = content.find(sep, actions_close + len("              ]," + sep + "            ),"))
if end_idx != -1:
    end_idx += len(sep)

replacement = f"""    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Notifications",
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$unreadCount",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ]
          ],
        ),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: InkWell(
                onTap: () => NotificationNotifier.instance.markAllAsRead(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.done_all_rounded, color: isDark ? Colors.white : AppColors.primaryGreen, size: 18),
                ),
              ),
            )
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        displacement: kToolbarHeight + 20,
        onRefresh: () => NotificationNotifier.instance.load(force: true),
        child: CustomScrollView(
          clipBehavior: Clip.none,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + kToolbarHeight,
              ),
            ),
""".replace('\n', sep)

new_content = content[:start_idx] + replacement + content[end_idx:]

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("SUCCESS: notifications_screen.dart updated")
