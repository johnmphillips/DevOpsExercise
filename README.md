# DevOps Exercise - John Phillips


## Assumptions

This solution is based on the following assumptions

- **AWS Free Tier** - This solution must run on my personal AWS account within the free tier resources
- **Application Code** - The solution will not change the application code or chosen technologies
- **Scalability** - The solution will not need to serve any more than the traffic used to complete & evaluate the exercise
- **Resiliency** - The scenario does not have any resiliency requirements

## Overview

I kept it quite simple, opting to deploy 3 ec2 instances which run their respective docker containers upon startup.

- The frontend server allows traffic on port 80 from anywhere
- The backend allows traffic on port 80 only from the frontend security group
- The elasticsearch server allows traffic on port 9200 only from the backend security group
- RDS Postgres Database that allows connections from the frontend security group and my IP
- All servers allow SSH connections from my personal IP address (defined in tfvars) and SSM using the aws console

There's some parts i didnt get to tackle such as

- Putting the instances in autoscaling groups behind load balancers to increase reliability
- ECS (i had doubts i could get this to work on free tier, so i didnt want to spend too long pursuing)
- Best practice secrets maangement for db credentials

There's also some manual steps (seeding the database and elasticsearch which i didnt have time to automate)

## Alternatives

For improvements to this design I would suggest

- **Switching Postgres for DynamoDB** - The data model is a single table, so could easily be modelled in dynamoDB. You would then be able to take advantage of the on demand nature of dynamodb to only pay for what you use, rather than running a postgres instance 24x7. DynamoDB also scales incredibly well and has the resiliency seen in managed AWS Services
- **Switching ElasticSearch for DynamoDB** - For the same reasons as above.
- **Moving the frontend & backend applications to AWS Lambda** - The simple nature of the frontend and backend applications would lend itself well to the serverless model, and would give built in scalability and resiliency benefits as well as allowing you to only pay for the compute power you use, rather than keep instances running 24x7

It's worth noting that these changes would make the app less portable if you wanted to host it outside of AWS.