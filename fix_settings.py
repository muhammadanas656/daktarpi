with open(r'c:\skills development\daktarpi\lib\features\menu\presentation\screens\settings_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if i >= 1344 and i <= 1354:
        continue
    new_lines.append(line)

replacement = """        Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: const CustomAppBar(title: "Settings"),
          // --- 📌 PRO FIX: Liquid Scroll & Frosted Glass Utility Header ---
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                ),
              ),
"""
new_lines.insert(1344, replacement)

with open(r'c:\skills development\daktarpi\lib\features\menu\presentation\screens\settings_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
