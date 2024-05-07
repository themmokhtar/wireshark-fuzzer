#!/bin/bash
# export LLVM_PROFILE_FILE="$1"
# echo "LLVM_PROFILE_FILE=$LLVM_PROFILE_FILE"uu

#!/bin/bash

# Path to the counter file
coverage_path=$1
counter_file=$2

# Function to increment the counter atomically
increment_counter() {
    (
        # Check if the counter file exists, if not, create it with an initial value of 0
        if [ ! -f "$counter_file" ]; then
            echo 0 > "$counter_file"
        fi

        flock -x 200

        # Read the current counter value
        count=$(cat "$counter_file")
        count=$((count + 1))

        # Write the new counter value
        echo $count > "$counter_file"

        # Return the new counter value
        echo $count
    ) 200>"$counter_file.lock"
}

# Function to update the coverage data atomically. This is super slow, but we don't care for now...
update_coverage() {
    (
        flock -x 200

        # Check if the coverage file exists, if not, create it
        if [ ! -f "$coverage_path/indexed.profdata" ]; then
            llvm-profdata merge -o $coverage_path/indexed.profdata $LLVM_PROFILE_FILE
            return
        fi

        # Merge the new coverage data with the existing data
        llvm-profdata merge -o $coverage_path/indexed.profdata $coverage_path/indexed.profdata $LLVM_PROFILE_FILE

    ) 200>"$coverage_path/coverage.lock"
}

# Usage example to generate a unique file name
export LLVM_PROFILE_FILE="$coverage_path/fuzzing-$(increment_counter).profraw"

shift
shift

$@


# Update the coverage data
update_coverage
# Remove the temporary coverage file
rm -rf $LLVM_PROFILE_FILE