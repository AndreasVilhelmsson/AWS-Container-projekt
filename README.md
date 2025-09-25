## Build & Push to ECR

> **Viktigt:** Fargate kör `X86_64`. Bygg imagen som `linux/amd64` för att undvika
> `exec format error`.

```bash
aws ecr get-login-password --region eu-west-1 \
  | docker login --username AWS --password-stdin 701055076605.dkr.ecr.eu-west-1.amazonaws.com

docker buildx build --platform linux/amd64 -t react-web .

docker tag react-web:latest 701055076605.dkr.ecr.eu-west-1.amazonaws.com/react-web:latest
docker push 701055076605.dkr.ecr.eu-west-1.amazonaws.com/react-web:latest
```

---

## Vad detta fixar (lessons learned → automatiserat)

- **Fel arkitektur** → `runtime_platform.cpu_architecture = "X86_64"` + `--platform linux/amd64` i bygget.
- **Health checks failar på SPA** → `health_check.path = "/index.html"` + `matcher 200-399`.
- **Tasks hinner inte bli healthy** → `health_check_grace_period_seconds = 30`.
- **Lååång draining** → `deregistration_delay = 60` på target group (snabbare rullningar).
- **Internetåtkomst för Fargate i public subnets** → `assign_public_ip = true`.

hybridlösning:
• Frontend: React byggd till statiska filer i Docker och körs i ECS Fargate bakom en ALB.
• Backend: Dina befintliga Lambda-funktioner + API Gateway + DynamoDB från serverless-lösningen.
• Kommunikation: React-appen anropar samma API endpoints som tidigare, så du slipper bygga en ny backend.

Det här ger dig flera fördelar: 1. Separation of concerns – backend (serverless) och frontend (container) kan versioneras och deployas oberoende. 2. Resilience – om du av någon anledning får problem i ECS-delen, fortsätter Lambda + DynamoDB ändå fungera. 3. Skalbarhet – ECS skalar webblagret (statiska assets, React) och API Gateway/Lambda skalar logiken. 4. Återanvändning – du fick direkt nytta av den backend du redan investerat tid i.

Vi har nu en fullstack AWS-app med en containeriserad frontend och en serverless backend

```mermaid
flowchart LR
%% Client
U[User / Browser]

%% Edge / DNS (optional custom domain)
subgraph Edge
CF[(Route53/Custom DNS)]
end

%% ALB + SG
subgraph VPC["VPC (default) 172.31.0.0/16"]
direction TB
subgraph PubA["Public Subnet A (AZ-1)"]
ALB[(Application Load Balancer)]
end
subgraph PubB["Public Subnet B (AZ-2)"]
end

    subgraph ECS["ECS Fargate Service: react-web-svc"]
      direction LR
      T1[(Task #1\nContainer: Nginx+React\nPort 80)]
      T2[(Task #2\nContainer: Nginx+React\nPort 80)]
    end

end

%% Serverless backend (out of VPC unless you attached VPC to Lambdas)
subgraph Serverless["Serverless Backend (managed)"]
APIGW[[API Gateway\n(HTTPS, REST/HTTP API)]]
L1((Lambda Functions))
DDB[(DynamoDB Table)]
end

%% Build & registry / observability
subgraph CICD["Build & Registry / Observability"]
ECR[(Amazon ECR\nreact-web:latest)]
CW[(CloudWatch Logs\n/ecs/react-web)]
IAM[(IAM Roles\n- TaskExecutionRole\n- TaskRole\n- GH OIDC Role)]
end

%% Edges
U -->|HTTP/HTTPS| CF
CF -->|HTTP/HTTPS| ALB
ALB -->|Forward :80\nTarget Group (ip)\nHealth: /index.html| T1
ALB -->|Forward :80\nTarget Group (ip)\nHealth: /index.html| T2

%% Frontend calls backend
T1 -->|HTTPS fetch\n/api/_| APIGW
T2 -->|HTTPS fetch\n/api/_| APIGW
APIGW --> L1
L1 --> DDB

%% Images & logs
T1 -. pulls image .-> ECR
T2 -. pulls image .-> ECR
T1 -. logs .-> CW
T2 -. logs .-> CW

%% Notes
classDef alb fill:#e6f3ff,stroke:#3a7bd5,stroke-width:1px;
classDef ecs fill:#e8ffe6,stroke:#36a35a,stroke-width:1px;
classDef srv fill:#fff5e6,stroke:#ff9800,stroke-width:1px;
classDef reg fill:#f0e6ff,stroke:#7b61ff,stroke-width:1px;

class ALB alb
class T1,T2 ecs
class APIGW,L1,DDB srv
class ECR,CW,IAM reg
```
