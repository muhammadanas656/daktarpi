path = r'c:\skills development\daktarpi\lib\features\medical_records\presentation\screens\medical_records_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

sep = '\r\n' if '\r\n' in content else '\n'

# Find the SliverAppBar block start and the line just before _buildSliverBody
start_marker = "              SliverAppBar("
end_marker = "              _buildSliverBody(isLocked),"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print(f"FATAL: start={start_idx}, end={end_idx}")
    exit(1)

replacement = f"""              SliverPadding({sep}                padding: EdgeInsets.only({sep}                  top: MediaQuery.paddingOf(context).top + kToolbarHeight,{sep}                ),{sep}              ),{sep}"""

new_content = content[:start_idx] + replacement + content[end_idx:]

# Now replace the Scaffold block to add extendBodyBehindAppBar and CustomAppBar
old_scaffold = f"        return Scaffold({sep}          extendBody: true,{sep}          backgroundColor: Theme.of(context).scaffoldBackgroundColor,{sep}          // THE FIX: Synchronized to use the liquid CustomScrollView from Settings!{sep}          body: CustomScrollView("

new_scaffold = f"""        return Scaffold({sep}          extendBodyBehindAppBar: true,{sep}          extendBody: true,{sep}          backgroundColor: Theme.of(context).scaffoldBackgroundColor,{sep}          appBar: CustomAppBar({sep}            title: "Medical Records",{sep}            actions: [{sep}              if (_hasSecurityConfigured){sep}                Padding({sep}                  padding: const EdgeInsets.only(right: 8.0),{sep}                  child: IconButton({sep}                    icon: Icon({sep}                      isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,{sep}                      color: isLocked ? AppColors.primaryGreen : Colors.grey,{sep}                    ),{sep}                    onPressed: _toggleProtection,{sep}                  ),{sep}                ),{sep}            ],{sep}          ),{sep}          // THE FIX: Synchronized to use the liquid CustomScrollView from Settings!{sep}          body: CustomScrollView("""

new_content = new_content.replace(old_scaffold, new_scaffold)

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("SUCCESS: medical_records_screen.dart updated")
