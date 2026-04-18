import os
import re

def replace_app_bar(file_path, title):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex to find the whole appBar: AppBar(...) block
    pattern = r'appBar:\s*AppBar\([\s\S]*?flexibleSpace:\s*ClipRRect\([\s\S]*?title:\s*Text\(\s*[\"\']' + title + r'[\"\'][\s\S]*?\),\s*\),'
    
    replacement = f"appBar: CustomAppBar(title: '{title}'),"
    
    new_content = re.sub(pattern, replacement, content)
    
    if new_content != content:
        # Add import if missing
        if 'custom_app_bar.dart' not in new_content:
            # find first import
            new_content = re.sub(r'(import .*?;)', r'\1\nimport \'../../../../core/widgets/custom_app_bar.dart\';', new_content, count=1)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print('Updated: ' + file_path)

replace_app_bar('lib/features/doctors/presentation/screens/featured_doctors_screen.dart', 'Featured Doctors')
replace_app_bar('lib/features/doctors/presentation/screens/popular_doctors_screen.dart', 'Popular Doctors')
replace_app_bar('lib/features/doctors/presentation/screens/global_search_screen.dart', 'Global Search')
