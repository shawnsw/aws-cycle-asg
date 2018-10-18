# AWS Cycle ASG

## Background
When we change the launch profile, or we want to roll out a new version of the application, we need to cycle instances in an ASG.

This can be done in two ways.

#### Rolling update

Basically you roll one instance at a time.
As each instance takes a long time (default 300s) to drain from ELB, if you have a lot of instances in the ASG, it can take a long time.

#### Blue/green deployment

In this way, you basically double the ASG, and then terminate old ones in one go. It's much more efficient.

## How does it work

* Double ASG max-size and desired-size
* Wait for all instances to come into service
* Detach old instances from ASG and ELB
* Terminate old instances
* Scale back

## How to use
```
./aws-cycle-asg -a asg_name -r aws_region -d detach_timeout
```

Default value:
```
aws_region: ap-southeast-2
detach_timeout: 300
```

Detach timeout can be found in the attribute `Deregistration delay` in the Target Group.
