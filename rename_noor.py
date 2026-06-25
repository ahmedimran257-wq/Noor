import os
import re

ROOT_DIR = r'c:\Users\imran\noor\lib'

# 1. First, rename files and directories
def rename_files_and_dirs(root_dir):
    # Rename bottom-up to avoid breaking paths
    for root, dirs, files in os.walk(root_dir, topdown=False):
        for name in files:
            if 'noor' in name.lower():
                new_name = re.sub(r'noor', 'mithaq', name, flags=re.IGNORECASE)
                os.rename(os.path.join(root, name), os.path.join(root, new_name))
        
        for name in dirs:
            if 'noor' in name.lower():
                new_name = re.sub(r'noor', 'mithaq', name, flags=re.IGNORECASE)
                os.rename(os.path.join(root, name), os.path.join(root, new_name))

# 2. Then, replace content in all files
def replace_content(root_dir):
    for root, dirs, files in os.walk(root_dir):
        for name in files:
            if not (name.endswith('.dart') or name.endswith('.arb')):
                continue
            
            filepath = os.path.join(root, name)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content = content
                # Replace 'Noor' with 'Mithaq'
                new_content = re.sub(r'\bNoor\b', 'Mithaq', new_content)
                new_content = re.sub(r'Noor(?=[A-Z])', 'Mithaq', new_content) # for NoorTextField etc where \b might not match if preceded by something, but usually it does. Actually \b matches word boundaries.
                
                # Replace 'noor_' with 'mithaq_' (for imports and file names and variables)
                new_content = re.sub(r'noor_', 'mithaq_', new_content)
                new_content = re.sub(r'_noor', '_mithaq', new_content)
                
                # Replace 'NOOR' with 'MITHAQ'
                new_content = re.sub(r'\bNOOR\b', 'MITHAQ', new_content)
                
                # Replace 'NoorApp' -> 'MithaqApp' (if \b didn't catch it)
                new_content = new_content.replace('NoorApp', 'MithaqApp')
                new_content = new_content.replace('noor.app', 'mithaq.app')

                # Replace Arabic text
                new_content = new_content.replace('نور', 'ميثاق')
                
                if content != new_content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated content in: {filepath}")
            except Exception as e:
                print(f"Error processing {filepath}: {e}")

if __name__ == '__main__':
    rename_files_and_dirs(ROOT_DIR)
    replace_content(ROOT_DIR)
    print("Done renaming in lib/")
