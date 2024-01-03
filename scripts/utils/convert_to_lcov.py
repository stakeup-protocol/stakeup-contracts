import json

def process_json_to_lcov(json_file, lcov_file):
    with open(json_file, 'r') as file:
        data = json.load(file)

    with open(lcov_file, 'w') as file:
        for filepath, filedata in data['data'].items():
            file.write(f'SF:{filepath}\n')

            first_element_skipped = False
            for item in filedata:
                # Skip the first element
                if not first_element_skipped:
                    first_element_skipped = True
                    continue

                start_line = item['startLine']
                hits = item['coverageHits']
                file.write(f'DA:{start_line},{hits}\n')
                # Process branchRecords if necessary
                for branch in item.get('branchRecords', []):
                    branch_line = branch['startLine']
                    branch_hits = branch['coverageHits']
                    file.write(f'DA:{branch_line},{branch_hits}\n')
            file.write('end_of_record\n')

process_json_to_lcov('wake-coverage.cov', 'lcov_wake.info')
