#!/bin/sh
echo "Extracting all Wallets ..."
echo "Get total number of wallets"
curl -X GET https://127.0.0.1:8090/api/v1/wallets \
-H 'Accept : application/json;charset=utf-8' \
--cacert ./state-demo/tls/edge/ca.crt \
--cert ./state-demo/tls/edge/client.pem --output  all_wallets.json
num_wallets=$(jq '.meta.pagination.totalEntries' all_wallets.json)
echo " $num_wallets "
echo " Get total number of pages "
# Round up to the next integer
num_pages=$(( ( num_wallets + 50 -1)/50 ))
echo " $num_pages "
echo " Creating final JSON sceleton "
rm -rf all_wallets.json
echo "{" >> all_wallets.json
echo '"all_wallets":[' >> all_wallets.json
# Loop through every available page and append the JSON data to the final output file
for i in $( seq 1 $num_pages); do
curl -X GET 'https://127.0.0.1:8090/api/v1/wallets?page=1&per_page=50' \
-H 'Accept: application/json;charset=utf-8' \
--cacert ./state-demo/tls/edge/ca.crt \
--cert ./state-demo/tls/edge/client.pem --http1.1 >> all_wallets.json
echo "," >> all_wallets.json
done

echo "]" >> all_wallets.json
echo "}" >> all_wallets.json
# Extract the ID elements of the JSON output
grep -Po '"id":.*?[^\\]",' all_wallets.json > output_wallet_id.txt
# Beautify the output and cut leading and traling characters
sed '{s/^.\{6\}//;s/.\{2\}$//}' output_wallet_id.txt > output_wallet_id_cleaned.txt
file="output_wallet_id_cleaned.txt"
# Write Start Time to the final output
rm -rf duration_check.sh
now=`date +%s`
echo "Start Time:" >> duration_check.sh
echo "$now" >> duration_check.sh
while IFS= read line; do
echo "Creating transaction ..."
curl -s -X POST https://localhost:8090/api/v1/transactions \
-H "Accept: application/json;charset=utf-8" \
-H "Content-Type: application/json;charset=utf-8" \
--cacert ./state-demo/tls/edge/ca.crt \
--cert ./state-demo/tls/edge/client.pem \
-d '{"destinations":[{"amount":100,"address":"'$line'"}],"source":{"accountIndex":2147483648,"walletId":"'$line'"},"spendingPassword":""}' \
--http1.1 &> /dev/null
done <"$file"
echo "Waiting for all Transactions to be sent ..."

echo $'\nAll transactions have been sent to the network ! !'
tx_sent=`date +%s`
echo "Finished sending transactions:" >> duration_check.sh
echo "$tx_sent" >> duration_check.sh
