#!/usr/bin/bash

show_usage() {
	echo "Script creating or importing AWS EC2 SSH key-pairs"
	echo "--------------------------------------------------"
	echo "Usage: $0 -h/--help"
	echo "Usage: $0 --action <create/import> --file <path-to-file> --name <name> --description <description>"
	echo ""
	echo "Example: $0 --action create --file /path/to/new_private_key.pem --name my-client-key --description \"My Client Key\""
    echo "Example: $0 --action import --file /path/to/existing_public_key.pub --name my-client-key --description \"My Client Key\""
	echo ""
	echo "** requires aws cli to be installed"
	echo "** https://aws.amazon.com/cli/"
}

# show usage if asked for help
if [[ ($1 == "--help") || $1 == "-h" ]]; then
	show_usage
	exit 0
fi

# iterate over arguments and create named parameters
while [ $# -gt 0 ]; do
	if [[ $1 == *"--"* ]]; then
		param="${1/--/}"
        declare $param="$2"
	fi
	shift
done

# if a property is missing, show usage and exit
if [ -z "$action" | -z "$file" | -z "$name" | -z "$description" ]; then
	show_usage
	exit 1
fi

# handle create key-pair action
if [ "$action" = "create" ]; then
    echo "creating a new key-pair named $name..."
    aws ec2 create-key-pair \
        --key-name $name \
        --tag-specifications "ResourceType=key-pair, Tags=[{Key=Name, Value=$description}]" \
        --query "KeyMaterial" --output text \
        > $file
    echo "key-pair created, private key is in $file."
    echo "please consider 'chmod 400 $file'"

# handle import key-pair action
elif [ "$action" = "import" ]; then
    echo "importing an existing key-pair from $file..."
    aws ec2 import-key-pair \
        --key-name $name \
        --public-key-material fileb:/$file \
        --tag-specifications "ResourceType=key-pair, Tags=[{Key=Name, Value=$description}]"
    echo "key-pair import and named $name."

# if action is not create nor import, show usage and exit
else
	show_usage
	exit 1
fi

echo ""
echo "Done!"
