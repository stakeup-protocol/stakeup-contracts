#!/bin/bash

import json

# Function to check if lcov is installed
check_and_install_lcov() {
    if ! command -v lcov &>/dev/null; then
        echo "lcov not found, attempting to install..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # Assumes Homebrew is installed
            brew install lcov
        else
            echo "Please install lcov manually."
            exit 1
        fi
    fi
}

## Activate the python virtual environment for wake

python3 -m venv venv

source venv/bin/activate

## Install the dependencies (if any)
pip install -r requirements.txt

# Run Wake testing environment and generates wake-coverage.cov
wake test ./tests/wake_testing --coverage

# deactivate python virtual environment
deactivate

# Clear files_with_lines_coverage_wake.txt before usage
>files_with_lines_coverage_wake.txt

# generates lcov.info
forge coverage --match-path ./src --report lcov

## Turn wake-coverage.cov into lcov format

# Initialize variables
current_file=""
end_line=0
line_hits=0
info_file="lcov_wake.info"

# Create or clear the info file
>"$info_file"

# Process each line of the wake-coverage.cov file
python ./scripts/utils/convert_to_lcov.py

## Prepare lcov.info for foundry

# Initialize variables
current_file=""
lines_found=0
lines_hit=0

# Clear files_with_lines_coverage.txt before usage
>files_with_lines_coverage_foundry.txt

# Call the function to check and install lcov
check_and_install_lcov

# Process each line of the LCOV report for foundry
while IFS= read -r line; do
    if [[ $line == LF:* ]]; then
        # Get the line count
        lines_found=${line#LF:}
    elif [[ $line == LH:* ]]; then
        # Get the line hit count
        lines_hit=${line#LH:}

        # Check if lines_found is equal to lines_hit
        if [[ $lines_found -eq $lines_hit ]]; then
            # Remember the current file as having 100% coverage
            echo "$current_file" >>files_with_lines_coverage_foundry.txt
        fi
    elif [[ $line == SF:* ]]; then
        # If the line contains "SF:", it's the start of a new file. Save the filename.
        current_file=${line#SF:}
    fi
done <lcov.info

## Prepare lcov_wake.info for wake

# Initialize variables
current_file=""
lines_found=0
lines_hit=0

# Clear files_with_lines_coverage.txt before usage
>files_with_lines_coverage_foundry.txt

# Call the function to check and install lcov
check_and_install_lcov

# Process each line of the LCOV report for foundry
while IFS= read -r line; do
    if [[ $line == LF:* ]]; then
        # Get the line count
        lines_found=${line#LF:}
    elif [[ $line == LH:* ]]; then
        # Get the line hit count
        lines_hit=${line#LH:}

        # Check if lines_found is equal to lines_hit
        if [[ $lines_found -eq $lines_hit ]]; then
            # Remember the current file as having 100% coverage
            echo "$current_file" >>files_with_lines_coverage_foundry.txt
        fi
    elif [[ $line == SF:* ]]; then
        # If the line contains "SF:", it's the start of a new file. Save the filename.
        current_file=${line#SF:}
    fi
done <lcov_wake.info

# Create a space-separated string of all file patterns
patterns_wake=$(cat files_with_lines_coverage_wake.txt | tr '\n' ' ')

# Create a space-separated string of all file patterns
patterns_foundry=$(cat files_with_lines_coverage_wake.txt | tr '\n' ' ')

# Now use single lcov --extract command with all file patterns
lcov --extract lcov.info $patterns_foundry --output-file lcov.info

# Now use single lcov --extract command with all file patterns
lcov --extract lcov_wake.info $patterns_wake --output-file lcov_wake.info

## make coverage directory
mkdir -p coverage

# Merge lcov files
lcov \
    --rc branch_coverage=1 \
    --add-tracefile lcov_wake.info \
    --add-tracefile lcov.info \
    --output-file merged-lcov.info \
    --no-checksum

# Filter out node_modules, test, and mock files
lcov \
    --rc branch_coverage=1 \
    --remove merged-lcov.info \
    "*lib*" "*mocks*" \
    --output-file coverage/filtered-lcov.info

# Generate summary
lcov \
    --rc branch_coverage=1 \
    --list coverage/filtered-lcov.info

# Open more granular breakdown in browser
if [ "$HTML" == "true" ]; then
    genhtml \
        --rc genhtml_branch_coverage=1 \
        --output-directory coverage \
        coverage/filtered-lcov.info

    # Detect the operating system
    case "$(uname -s)" in
    Darwin*) open_cmd="open" ;;           # macOS
    Linux*) open_cmd="xdg-open" ;;        # Linux
    CYGWIN* | MINGW*) open_cmd="start" ;; # Windows (Cygwin/MinGW)
    *) open_cmd="echo Cannot automatically open HTML report on this OS: " ;;
    esac

    # Execute the command to open HTML in browser
    $open_cmd coverage/index.html
fi

# Delete temp files
rm lcov.info files_with_lines_coverage_wake.txt files_with_lines_coverage_foundry.txt lcov_wake.info merged-lcov.info wake-coverage.cov json wake_coverage.info
