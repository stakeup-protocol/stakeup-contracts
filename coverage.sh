#!/bin/bash

echo "Starting coverage script..."

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

echo "Activating the python virtual environment for wake..."

python3 -m venv venv

source venv/bin/activate

## Install the dependencies (if any)
echo "Installing dependencies..."
pip install -r requirements.txt

# Run Wake testing environment and generates wake-coverage.cov
echo "Running Wake testing environment..."
wake test ./tests/wake_testing --coverage

# deactivate python virtual environment
deactivate

# Clear files_with_lines_coverage_wake.txt before usage
>files_with_lines_coverage_wake.txt

# Install forge dependencies (if needed)
echo "Installing forge dependencies..."
forge install

# generates lcov.info
echo "Generating lcov for forge coverage..."
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
            echo "100% coverage in $current_file"
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
>files_with_lines_coverage_wake.txt

# Call the function to check and install lcov
check_and_install_lcov

# Process each line of the LCOV report for wake
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
            echo "100% coverage in $current_file"
            echo "$current_file" >>files_with_lines_coverage_wake.txt
        fi
    elif [[ $line == SF:* ]]; then
        # If the line contains "SF:", it's the start of a new file. Save the filename.
        current_file=${line#SF:}
    fi
done <lcov_wake.info

# Create a space-separated string of all file patterns
patterns_wake=$(cat files_with_lines_coverage_wake.txt | tr '\n' ' ')

# Create a space-separated string of all file patterns
patterns_foundry=$(cat files_with_lines_coverage_foundry.txt | tr '\n' ' ')

# Now use single lcov --extract command with all file patterns
lcov --extract lcov.info $patterns_foundry --output-file lcov.info

# Now use single lcov --extract command with all file patterns
lcov --extract lcov_wake.info $patterns_wake --output-file lcov_wake.info

## make coverage directory
mkdir -p coverage

# Foundry uses relative paths but Wake uses absolute paths.
# Convert absolute paths to relative paths for consistency.
sed -i -e "s/\/.*$(basename "$PWD").//g" lcov_wake.info

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
echo "Generating coverage summary..."
lcov \
    --rc branch_coverage=1 \
    --list coverage/filtered-lcov.info

# Initialize a variable to track the HTML flag
generate_html=false

# Process input arguments
while [ "$1" != "" ]; do
    case $1 in
    --html)
        generate_html=true
        ;;
    esac
    shift
done

# Generate and open HTML report based on the flag
if [ "$generate_html" = true ]; then
    echo "Generating HTML coverage report..."
    genhtml --rc branch_coverage=1 --output-directory coverage coverage/filtered-lcov.info

    echo "Detecting operating system for opening the report..."
    case "$(uname -s)" in
    Darwin*) open_cmd="open" ;;
    Linux*) open_cmd="xdg-open" ;;
    CYGWIN* | MINGW*) open_cmd="start" ;;
    *) open_cmd="echo Cannot automatically open HTML report on this OS: " ;;
    esac

    echo "Opening HTML report in browser..."
    $open_cmd coverage/index.html
else
    echo "HTML report generation skipped."
fi

echo "Cleaning up temporary files..."
# rm lcov.info files_with_lines_coverage_wake.txt files_with_lines_coverage_foundry.txt lcov_wake.info merged-lcov.info wake-coverage.cov
# rm -rf venv

echo "Coverage script completed."
