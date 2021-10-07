#!/bin/sh

echo "Get total number of transactions ..."
curl https://127.0.0.1:8090/api/v1/transactions \
--cacert ./state-demo/tls/edge/ca.crt \
--cert ./state-demo/tls/edge/client.pem --http1.1 --output all_transactions.json
num_transactions=$( jq '.meta.pagination.totalEntries' all_transactions.json )
echo "$num_transactions"
echo "Get total number of pages"

# Round up to the next integer
num_pages=$(( ( num_transactions + 50 -1) /50 ))
echo "$num_pages"
while sleep 1;
do
rm -rf all_transactions.json
# Boolean to assess if all transactions are in blocks
file_is_ok=true
# Boolean to stop checking transactions due to some still
# being applied , jump again to outer while loop and wait for 1 sec
intercept_check=false
# Loop through every available page and check the transaction
#states , fetching the newest transactions first
for i in $( seq 1 $num_pages ); do
# Do an API call to get all TXs
curl -X GET 'https://127.0.0.1:8090/api/v1/transactions?sort_by=DES\[created_at\]&page='$i'&per_page=50' \
--cacert ./state-demo/tls/edge/ca.crt \
--cert ./state-demo/tls/edge/client.pem --http1.1 --output output_tx.json
# Extract the tag elements of the TX json file
grep -Po '"tag":.*?[^\\]",' output_tx.json > output_tx_cleaned.txt
# Given the cleaned up TX states , check if the file is OK
file="output_tx_cleaned.txt"
echo "checking Transactions for page '$i'"
# Checking the lines of the tx output
while IFS= read line; do
if [[ "$line" == *"applying"* ]]; then
echo "$line"
file_is_ok=false
intercept_check=true
break
fi
done <"$file"
if [[ $intercept_check == true ]]; then
echo "intercepting transaction check at page
' $i '"
break
fi
done
# Check if all Transactions are OK.If so , then write final
# commands to the evaluation script
if [[ $file_is_ok == true ]]; then
echo "Transactions are all applied !"
now=`date +%s`
echo "End Time:" >> duration_check.sh
echo "$now" >> duration_check.sh
# Get total number of blocks
curl -X GET https://localhost:8090/api/v1/node-info \
-H 'Accept: application/json;charset=utf-8' \
--cacert ./state-demo/tls/edge/ca.crt \
--cert ./state-demo/tls/edge/client.pem --output total_blocks.json
echo "Total Blocks created:" >> duration_check.sh
num_blocks=$( jq '.data.blockchainHeight.quantity' total_blocks.json )
echo "$num_blocks" >> duration_check.sh
exit 1
fi
done
