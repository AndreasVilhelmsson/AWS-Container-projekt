# WebbAppContainer – Projektrapport

## Introduktion

Den här rapporten beskriver hur jag byggde **WebbAppContainer**, en containerbaserad variant av mitt kontaktformulär. Lösningen ersätter den statiska S3-hostingen från serverless-projektet med en fullt containeriserad frontend som körs på AWS Fargate, men använder samma backend-API som jag byggde tidigare. Syftet var att lära mig hur man driver en modern React-applikation i ECS, hanterar hela kedjan från Docker build till lastbalanserad drift och jämföra kostnads- och operationsaspekter mot den serverlösa motsvarigheten.

## Mål och omfattning

- Förpacka frontenden i en Docker-image och publicera den i ECR.
- Köra containern på en skalbar Fargate-tjänst bakom ett Application Load Balancer.
- Återanvända det befintliga serverless-API:t utan kodförändringar i backend.
- Automatisera infrastrukturen med Terraform och skapa ett reproducerbart deployflöde.

## Genomförande steg för steg

1. **Förutsättningar för VPC.** Projektet lutar sig mot samma default-VPC som används av andra labbar. Jag angav VPC och publika subnät i `infra/terraform.tfvars` så att både ALB och ECS kan få publik åtkomst via två AZ.
2. **Terraform-initiering.** Med `terraform init`/`apply` skapades ECR-repositoriet och all nätverks- och säkerhetsinfrastruktur enligt filerna i `infra/`. Moduler ersattes inte – allt ligger i ett platt upplägg för att lätt följa resursdefinitionerna.
3. **ECR och behörigheter.** Resursen `aws_ecr_repository.app` (`infra/main.tf:12`) aktiverar scanning on push och `force_delete` så att labbresurser rensas automatiskt. IAM-rollerna för ECS execution och task ligger i `infra/ecs.tf:12` respektive `infra/ecs.tf:32` och ger de behörigheter som behövs för att dra bilder från ECR och skriva loggar.
4. **Ladda upp containern.** Jag skrev en tvåstegs Dockerfile (`app/Dockerfile:1`) som bygger React-appen i Node 22 och serverar den statiskt via `nginx:alpine`. `docker buildx build --platform linux/amd64` ser till att imagen kör på Fargates x86_64 runtime.
5. **ECS-kluster och service.** Terraform definierar klustret (`infra/ecs.tf:45`), task definitionen med loggkonfiguration (`infra/ecs.tf:50`) och servicen (`infra/ecs.tf:93`). Target groupens hälsokontroll pekar mot `/index.html` (`infra/alb.tf:66`), vilket var avgörande för att ALB skulle kunna markera containern som frisk.
6. **Frontend-anslutningar.** React-appen hämtar samma API som serverless-versionen via `VITE_API_BASE` (`app/frontend/src/api/client.ts:10`). Formuläret och listan återvinner komponenterna från tidigare projekt (`app/frontend/src/App.tsx:1`), och det finns fortfarande en hook (`app/frontend/src/hooks/useMessages.ts:4`) om jag vill bryta ut logiken senare.
7. **Deployflöde.** Scriptet `deploy.sh` (`deploy.sh:5`) loggar in mot ECR, bygger imagen med en git-baserad tagg, pushar både `latest` och commit-taggen (`deploy.sh:41`), och triggar en rolling update på Fargate (`deploy.sh:51`). När Terraform och scriptet körts kan ALB-url:en öppnas i webbläsaren.
8. **Autoskalning.** Efter att ECS-servicen skapats lägger Terraform till ett App Auto Scaling-target (`infra/ecs.tf:123`) som sätter min/max-kapacitet (1–4 tasks som standard) och en CPU-baserad Target Tracking-policy (`infra/ecs.tf:132`). Policyn skalar ut om genomsnittlig CPU överstiger 50 % och skalar in när lasten sjunker.
9. **Verifikation.** Jag kontrollerade att ALB target group var grön (`Images/targetgroups.jpg`), att containern rullade på två tasks (`Images/ecs.jpg`) och att frontenden fungerade via `Images/frontendUI.jpg`.

## Arkitekturöversikt

Arkitekturen består av fyra huvuddelar:

- Slutanvändaren når applikationen via ett internet-exponerat ALB som lyssnar på port 80 (`infra/alb.tf:49`).
- ALB routar trafiken till ECS Fargate-tasks i två publika subnät som ligger bakom en hårt limiterad säkerhetsgrupp (`infra/alb.tf:33`).
- Containern kör Nginx och levererar den bundlade React-applikationen. Efter att sidan laddats gör JavaScript-anropen vidare till det befintliga serverless-API:t via HTTPS.
- CloudWatch Logs grupperar containerloggar per tjänst (`infra/ecs.tf:6`), och ECR håller containerimagens versioner tillgängliga (`infra/main.tf:12`).
- Autoskalningen håller DesiredCount inom spannet 1–4 tasks och balanserar CPU-last utan manuell inblandning (`infra/ecs.tf:123`).

Resultatet är en klassisk container-setup i AWS där endast frontenden kör i ECS, men backend fortsatt lever i Lambda/API Gateway. Det ger en bra jämförelse i kostnad, svarstider och drift jämfört med S3 + CloudFront-lösningen.

### Arkitekturskiss i Cloudcraft

För att visualisera strukturen skapade jag en Cloudcraft-skiss med följande komponenter:

- `Application Load Balancer` i publika subnät, kopplad till samma säkerhetsgrupp som i Terraform.
- `ECS Fargate Service` med autoskalning (min/max 1–4 tasks) och health check via `/index.html`.
- En "Serverless API"-nod som representerar API Gateway + Lambda-backendet.
- DynamoDB-tabellen `ContactMessages` kopplad till Lambda.

Jag aktiverade "Show connections" och drog trafikflödet `User → ALB → ECS Service → Serverless API → DynamoDB`. Lägg gärna till anteckningar om CPU-målvärdet (50 %) och exportera bilden i hög upplösning till `Images/cloudcraft.png` när skissen är klar.

![ALB i drift](Images/alb.jpg)

![ALB Target groups](Images/targetgroups.jpg)

![ECS service och tasks](Images/ecs2.jpg)

![ECR repositorium](Images/ecr2.jpg)

## Flödesdiagram

```mermaid
graph LR
    A[Besökare i webbläsare] -->|HTTP 80| B(ALB)
    B --> C{{ECS Fargate Service<br/>Target Tracking Autoscaling}}
    C --> D[Nginx container]
    D -->|API-kall| E[API Gateway]
    E --> F[Lambda]
    F --> G[(DynamoDB)]
    F --> H[CloudWatch Logs]
    C --> I[ECR repository]
    I -.->|Pull image| C

    classDef autoscale fill:#fde68a,stroke:#f97316,stroke-width:2px,color:#1f2937;
    class C autoscale;
```

Autoskalningen sker i nod `C`, som är markerad med gul bakgrund i diagrammet. Du kan även bädda in samma mermaid-kod i exempelvis Notion eller GitHub för att få ett renderat flödesschema.

## Infrastruktur som kod

Terraform-koden är uppdelad efter resurstyp för tydlighet:

- `infra/network.tf:10` validerar den VPC jag pekar ut och återexponerar subnäten som output.
- Säkerhetsgrupperna skiljer på publik åtkomst (ALB) och intern trafik (tasks) i `infra/alb.tf:6` respektive `infra/alb.tf:27`.
- EC2 behövs inte alls – `infra/ecs.tf:50` låser task definitionen till Fargate med `awsvpc`-nätverksmode, `cpu=256` och `memory=512` för att hålla kostnaderna nere.
- Autoskalningsmålet `aws_appautoscaling_target.ecs_service` (`infra/ecs.tf:123`) och CPU-policyn (`infra/ecs.tf:132`) justerar DesiredCount mellan `min_capacity` och `max_capacity`. Trösklarna går att styra via variabler i `infra/variables.tf:42`.
- Variabler som `desired_count`, `health_check_path` och `container_port` är parametriserade (`infra/variables.tf:23`), vilket gjort det lätt att experimentera med fler instanser och andra portar.
- Output-värdena (`infra/outputs.tf:1`) ger mig repository-url:en så att deployscriptet kan lösa fullständigt image-namn.

### Konsolskärmdumpar

- ECR-repositoriet med versionshistorik (`Images/ecr.jpg`, `Images/ecr2.jpg`, `Images/ecr3.jpg`).
- ECS cluster- och servicevy med DesiredCount och autoskalningsgränser (`Images/ecs.jpg`, `Images/ecs2.jpg`).
- ALB listener och target group-status (`Images/alb.jpg`, `Images/alb2.jpg`, `Images/targetgroups.jpg`).
- Frontendgränssnittet efter deploy (`Images/frontendUI.jpg`).

## Applikation och container

- Dockerfilen (`app/Dockerfile:1`) bygger alltid från en ren node-bild med `npm ci`, vilket garanterar reproducerbara builds. Static assets kopieras in i en minimal Nginx-miljö för bästa starttid.
- Frontendens byggkommandon finns i `app/frontend/package.json:6` och körs automatiskt i Dockersteget. Loki testkörning sker lokalt med `npm run dev` innan bygg.
- `App.tsx` (`app/frontend/src/App.tsx:7`) hämtar och skickar meddelanden, visar laddning/felstate och återanvänder komponenterna `MessageForm` och `MessageList`.
- API-klienten (`app/frontend/src/api/client.ts:12`) slår mot `/messages` och är kompatibel med den befintliga DynamoDB-modellen (`id`, `name`, `message`, `createdAt`).
- SCSS-variablerna (`app/frontend/src/styles/_variables.scss:1`) används för att ge container-projektet ett eget tema.

## Drift- och säkerhetsaspekter

- Maliciös trafik stoppas på två nivåer: ALB-säkerhetsgruppen släpper bara in HTTP på port 80 och task-gruppen accepterar enbart trafik från ALB (`infra/alb.tf:33`).
- `assign_public_ip = true` i `infra/ecs.tf:107` säkerställer utgående internetåtkomst för Nginx (t.ex. för att hämta den serverless-API-destinationen), men jag kan senare växla till NAT + privata subnät.
- Rolling updates styrs av `deployment_minimum_healthy_percent` och `deployment_maximum_percent` (`infra/ecs.tf:103`), vilket ger noll-downtime när en ny image rullas ut. Target Tracking-policyn kompletterar detta genom att automatiskt starta fler tasks när CPU:n blir för hög och minska kapaciteten vid låg last (`infra/ecs.tf:132`).
- LoggRetentionen på 14 dagar (`infra/ecs.tf:6`) balanserar insyn och kostnad.
- Image scanning är påslaget i ECR (`infra/main.tf:15`), vilket ger larm om kända sårbarheter direkt vid push.

## Driftsättning

Helhetsflödet består av tre huvudkommandon:

```bash
# 1. Provisionera eller uppdatera infrastrukturen
cd infra
terraform init
terraform apply

# 2. Bygg och pusha imagen + rulla ut ECS
cd ..
bash deploy.sh

# 3. Validera
aws ecs describe-services --cluster react-web-cluster --services react-web-svc
open http://<alb-dns>
```

Scriptet fångar vanliga misstag (ingen Docker-daemon, avsaknad av Dockerfile) och taggar imagen med både commit-hash och `latest`. AWS CLI-anropet `aws ecs update-service --force-new-deployment` i `deploy.sh:51` säkerställer att den nya imagen används utan att behöva uppdatera task definitionen manuellt.

## Testning och validering

- Manuell sluttest gjordes mot ALB-DNS (`Images/frontendUI.jpg`).
- Target groupens health checks bevakades under utrullning (`Images/targetgroups.jpg`).
- CloudWatch Logs verifierade att Nginx startade och returnerade 200-responser.
- Autoskalningen verifierades genom att simulera last och se att `aws ecs describe-services` rapporterade hur DesiredCount höjdes över 2 när CPU-kravet triggades.
- Lokal utveckling sker fortfarande med `npm run dev` och backendens `sam local start-api`, vilket gör att jag kan testa UI:t snabbt innan en containerbuild.
- För att reglera regressioner planerar jag att använda samma Postman-collection som i serverless-projektet, men komplettera den med ett UI-smoketest mot ALB.

## Utmaningar

- Hälsokontrollerna på ALB krävde att jag pekade mot `/index.html`; när jag använde `/` markerades instanserna som sjuka. Det löstes genom `var.health_check_path` (`infra/variables.tf:37`) och dess användning i target groupen.
- Fargate accepterar inte ARM-containers, så på min M1-maskin var `--platform linux/amd64` obligatoriskt (`deploy.sh:41`). Utan det fick jag "exec format error" när tasken startade.
- Jag behövde öka `health_check_grace_period_seconds` till 30 sekunder (`infra/ecs.tf:100`) för att ge Nginx tid att komma upp innan ALB börjar testa den.

## Fortsatt arbete

1. Sätt upp HTTPS via ACM-certifikat och en `aws_lb_listener` på port 443.
2. Flytta ECS-tasks till privata subnät och använd NAT Gateway för utgående trafik.
3. Automatisera deployflödet i GitHub Actions med `terraform plan` + `docker build` + `aws ecs deploy`.
4. Implementera syntetiska tester (Pingdom/Route53 health checks) mot ALB för tidig larmning.
5. Lägga till en RequestCount-baserad skalningspolicy och/eller min/max justeringar för nattdrift.

## Slutsats

WebbAppContainer-projektet uppfyllde målet att köra samma frontend i en containerdriven miljö utan att röra backendkoden. Med Terraform, Docker och ett enkelt deployscript går det snabbt att bygga om imagen och rulla ut nya UI-versioner. Arkitekturen ger mig bättre kontroll över nätverkslagret och gör det lätt att koppla på fler containeriserade komponenter i framtiden, samtidigt som den delar dataflöde och logik med den tidigare serverless-lösningen.
