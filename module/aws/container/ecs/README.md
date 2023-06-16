# ec2-asg

EC2 Auto Scaling Group template
Wrong but you get the flow

```mermaid
flowchart LR
    Inbound_traffic -- HTTP: 80 --> ALB -- HTTP: server_port --> ECS
    ECS --> task_1
    task_1 --> ASG_on_demand & ASG_spot
    ASG_on_demand --> EC2_on_demand_1 & EC2_on_demand_2
    ASG_spot --> EC2_spot_1 & EC2_spot_2
    ECS --> task_2
```

# network mode

- awsvpc
  - for fargate
- bridge   
  - for EC2 with many instances, it allows dynamic mapping
- host
  - for EC2 with a single instance, cannot have dynamic port mapping, hence it is not made for many instances because a port can be taken by only one instance. But it is more performant than bridge network.