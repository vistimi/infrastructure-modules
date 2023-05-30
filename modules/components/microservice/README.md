Pipeline flow deprecated:

```mermaid
flowchart LR
    TF_ecr-->GH_ecr;
    GH_ecr-->TF_ecs;
    TF_env-->GH_env;
    GH_env-->TF_ecs;
    TF_ecs-->GH_ecs;
```