path = r'c:\skills development\daktarpi\lib\features\medical_records\presentation\screens\add_record_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

sep = '\r\n' if '\r\n' in content else '\n'

# Find the SliverAppBar block and replace it
start_marker = "            SliverAppBar("
end_marker = "            SliverPadding("

start_idx = content.find(start_marker)
end_idx = content.find(end_marker, start_idx)

if start_idx == -1 or end_idx == -1:
    print(f"FATAL: start={start_idx}, end={end_idx}")
    exit(1)

replacement = f"            SliverPadding({sep}              padding: EdgeInsets.only({sep}                top: MediaQuery.paddingOf(context).top + kToolbarHeight,{sep}              ),{sep}            ),{sep}"

new_content = content[:start_idx] + replacement + content[end_idx:]

# Now add extendBodyBehindAppBar and CustomAppBar to the Scaffold
# The scaffold currently is: child: Scaffold(\n        backgroundColor: Colors.transparent,\n        extendBody: true,\n        body: CustomScrollView(

old_scaffold = f"      child: Scaffold({sep}        backgroundColor: Colors.transparent,{sep}        extendBody: true,{sep}        body: CustomScrollView("

# Build the dynamic title
new_scaffold = f"""      child: Scaffold({sep}        extendBodyBehindAppBar: true,{sep}        backgroundColor: Colors.transparent,{sep}        extendBody: true,{sep}        appBar: CustomAppBar({sep}          title: widget.recordToEdit != null ? "Edit Record" : "Add Records",{sep}        ),{sep}        body: CustomScrollView("""

new_content = new_content.replace(old_scaffold, new_scaffold)

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("SUCCESS: add_record_screen.dart updated")
