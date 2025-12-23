
import re
import sys

def validate_bash_if_fi(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()

    stack = []
    errors = []

    # Regex to find if/fi/else/elif
    # We need to ignore comments and strings. 
    # This is a simple parser, might not catch everything but better than grep.
    
    for i, line in enumerate(lines):
        line_num = i + 1
        original_line = line.strip()
        
        # Remove comments
        if '#' in line:
            line = line[:line.index('#')]
        
        line = line.strip()
        if not line:
            continue

        # Check for start of string and ignore content? 
        # A full parser is hard. 
        # Let's try to match "if " at start of command, and "fi" at start of command.
        # But handle "if" inside strings (usually double quotes). 
        
        # Simplified approach: Remove all double-quoted strings first.
        # This handles the jq cases like "if .id == $id then" inside strings.
        
        # Remove \" first
        line_no_quotes = re.sub(r'\\.', '', line) 
        # Remove "..."
        line_no_strings = re.sub(r'"[^"]*"', '""', line_no_quotes)
        # Remove '...'
        line_no_strings = re.sub(r"'[^']*'", "''", line_no_strings)

        tokens = re.split(r'[\s;]+', line_no_strings)
        
        # Check tokens
        for token in tokens:
            if token == 'if':
                # Check if it's "if [[" or "if command"
                # make sure it's not part of a word like "shift" or "diff" (split handles this)
                stack.append(line_num)
            elif token == 'fi':
                if not stack:
                    errors.append(f"Line {line_num}: Unexpected 'fi'")
                else:
                    stack.pop()
    
    if stack:
        for ln in stack:
            errors.append(f"Line {ln}: Unclosed 'if'")

    if not errors:
        print("Structure seems valid.")
        return 0
    else:
        for e in errors:
            print(e)
        return 1

if __name__ == "__main__":
    sys.exit(validate_bash_if_fi(sys.argv[1]))
