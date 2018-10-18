#!/bin/bash

# AWS Cycle ASG v1.0
# https://github.com/shawnxlw/aws-cycle-asg

# Copyright (C) 2017 Shawn Wang
#
# You may use, distribute or modify this software under the terms of the MIT license.
#
# You should have received a copy of the MIT license with the software. 
# If not, you can obtain a copy from: https://opensource.org/licenses/MIT


# Set defaults
detach_delay=300
region="ap-southeast-2"

# Handle input
while getopts :a:r:d: opt
	do
		case $opt in
			a) asg_name="$OPTARG";;
			r) region="$OPTARG";;
			d) detach_delay="$OPTARG";;
			*) echo "Input error" 1>&2 ; exit 64 ;;
		esac
	done
if [[ -z $asg_name ]]
	then echo "Please specify an Auto Scaling Group name." 1>&2 ; exit 64
fi

# Get a dump of ASG
asg_result=`aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "$asg_name" --region $region`
# Validate ASG
if [[ `echo -e "$asg_result" | grep -c "AutoScalingGroupARN"` > 1  ]]
	then echo "More than one Auto Scaling Group found with specified name." 1>&2 ; exit 64
fi

if [[ `echo -e "$asg_result" | grep -c "AutoScalingGroupARN"` < 1 ]]
	then echo "Specified Auto Scaling Group was not found." 1>&2 ; exit 64
fi

# ASG max-size
asg_initial_max_size=`echo $asg_result | awk '/MaxSize/{ print $2 }' RS=,`
asg_temporary_max_size=$(($asg_initial_max_size*2))
# ASG desired-capacity
asg_initial_desired_capacity=`echo $asg_result | awk '/DesiredCapacity/{ print $2 }' RS=,`
asg_temporary_desired_capacity=$((asg_initial_desired_capacity*2))
# List of instance ids in the ASG
asg_instance_ids=`echo "$asg_result" | grep InstanceId | sed 's/.*i-/i-/' | sed 's/",//' | paste -s -d " " -`

# Exit if the max-size of the ASG is zero
if [[ $asg_initial_max_size -eq 0 ]]
	then echo "$asg_name has a max-size of 0. Exiting..." ; exit 79
fi

# Echo a list of Instances in the ASG
echo -e "Instances in Auto Scaling Group $asg_name:\n$asg_instance_list\n"

# Increse ASG max-size
echo -e "$asg_name has a max-size of $asg_initial_max_size. Increasing max-size to $asg_temporary_max_size.\n"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --region $region --max-size=$asg_temporary_max_size

# Increase ASG desired-size
echo -e "$asg_name has a desired-capacity of $asg_initial_desired_capacity. Increasing desired-capacity to $asg_temporary_desired_capacity.\n"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --region $region --desired-capacity=$asg_temporary_desired_capacity

# Wait for all instances to come into service
inservice_instance_count=0
echo -e "Waiting for all instances to come into service\n"
while [[ inservice_instance_count -lt asg_temporary_desired_capacity ]]
	do
		echo -n "."
		sleep 10
		inservice_instance_count=`aws autoscaling describe-auto-scaling-instances --output text | grep $asg_name | grep InService | wc -l`
	done

# Detach old instances from ASG
echo -e "\n\nDetaching instances from ASG...\n"
aws autoscaling detach-instances --instance-ids $asg_instance_ids --auto-scaling-group-name $asg_name --should-decrement-desired-capacity > /dev/null
sleep $detach_delay
sleep 60

# Terminate old instances
echo -e "Terminating $asg_instance...\n"
aws ec2 terminate-instances --instance-ids $asg_instance_ids > /dev/null

# Return to initial max-size
echo -e "Returning the max-size of $asg_name to $asg_initial_max_size.\n"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --region $region --max-size=$asg_initial_max_size

# Return to initial desired-capacity
echo -e "Returning the desired-capacity of $asg_name to $asg_initial_desired_capacity.\n"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --region $region --desired-capacity=$asg_initial_desired_capacity