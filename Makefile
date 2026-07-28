INSTANCE_ID := i-00ca0ff8512ddd2b3
REGION      := eu-central-1
APP_URL     := https://sockshop-staging.link

.PHONY: up down status url

## Start the app (instance boots in ~2 minutes)
up:
	aws ec2 start-instances --region $(REGION) --instance-ids $(INSTANCE_ID) --output text --query 'StartingInstances[0].CurrentState.Name'
	@echo "Starting... app will be ready at $(APP_URL) in ~2 minutes"

## Stop the app manually (also auto-stops after 30 min idle)
down:
	aws ec2 stop-instances --region $(REGION) --instance-ids $(INSTANCE_ID) --output text --query 'StoppingInstances[0].CurrentState.Name'

## Show current instance state
status:
	@aws ec2 describe-instances --region $(REGION) --instance-ids $(INSTANCE_ID) \
		--query 'Reservations[0].Instances[0].State.Name' --output text

## Print the app URL
url:
	@echo $(APP_URL)

gen-complete-demo:
	make -C deploy/kubernetes docker-gen-complete-demo

check-generated-files:
	make -C deploy/kubernetes docker-check-complete-demo
