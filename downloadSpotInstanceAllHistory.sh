#!/bin/bash


# --- SETTINGS ---

# AWS
AWS_ACCESS_KEY=$(aws configure get aws_access_key_id)
AWS_SECRET_KEY=$(aws configure get aws_secret_access_key)
AWS_REGION=$(aws configure get region)

# EC2
EC2_ACCESS="-O $AWS_ACCESS_KEY -W $AWS_SECRET_KEY"

# S3
S3_BUCKET_NAME=kmu-spot-instance-all-history

# CONSTANTS
START_TIME=$(date +%Y-%m-01T00:00:00 -d '1 month ago')
END_TIME=$(date +%Y-%m-01T00:00:00)
FILE_NAME=$(date +%Y%m -d '1 month ago').json


echo test > test
aws s3 cp test s3://$S3_BUCKET_NAME/test
exit 0


# --- FETCHING SPOT-PRICE-HISTORY FOR ALL REGIONS ---

echo "" > $FILE_NAME

echo '{' >> $FILE_NAME
echo '  "spot-price-history": [' >> $FILE_NAME

regions=$(ec2-describe-regions $EC2_ACCESS | awk '{print $2}')

region_count=0
history_count=0

for region in $regions
do
    region_count=$(expr $region_count + 1)

    echo -n "Fetching $region's spot price history: "

    spot_price_history=$(ec2-describe-spot-price-history $EC2_ACCESS --region $region -s $START_TIME -e $END_TIME | awk '{print $6,$4,$5,$2,$3}')

    cmp=0
    for history in $spot_price_history
    do
        history_count=$(expr $history_count + 1)

        cmp=$(expr $cmp % 5 + 1)

        case $cmp in
        1) # az: Available Zone
            if [ $history_count -ne 1 ]
            then
                echo '      },' >> $FILE_NAME
            fi

            echo '      {' >> $FILE_NAME
            echo '          "az": "'$history'",' >> $FILE_NAME;;
        2) # it: Instance Type
            echo '          "it": "'$history'",' >> $FILE_NAME;;
        3) # pd: Product Description
            echo '          "pd": "'$history'",' >> $FILE_NAME;;
        4) # sp: Spot Price
            echo '          "sp": "'$history'",' >> $FILE_NAME;;
        5) # ts: Timestamp
            echo '          "ts": "'$history'"' >> $FILE_NAME;;
        esac
    done
    
    echo "Complete"
done

echo

echo '      }' >> $FILE_NAME
echo '  ]' >> $FILE_NAME
echo '}' >> $FILE_NAME

aws s3 cp $FILE_NAME s3://$S3_BUCKET_NAME/$FILE_NAME
