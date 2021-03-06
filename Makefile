# Include environment variables for testing/building via docker compose
include build.env
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
export

IMAGE_NAME=722249479844.dkr.ecr.us-east-1.amazonaws.com/rsyslog-kafka
define docker_tag_latest
	docker tag $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest
endef

build:
	$(info ## build $(VERSION) ($(BUILD_DATE)).)
	docker-compose -f docker-compose.yml build --build-arg RSYSLOG_VERSION --build-arg VERSION --build-arg BUILD_DATE --build-arg DISABLE_YUM_MIRROR=true --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy
	$(call docker_tag_latest)

rebuild:
	$(info ## re-build $(VERSION) ($(BUILD_DATE)).)
	docker-compose -f docker-compose.yml build --no-cache --pull --build-arg RSYSLOG_VERSION --build-arg VERSION --build-arg BUILD_DATE --build-arg DISABLE_YUM_MIRROR=true --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy
	$(call docker_tag_latest)

push: build ecr-auth
	docker push $(IMAGE_NAME):latest

ecr-auth: ## authorize CLI for doing AWS ECR commands / pushes
	@eval $(CMD_REPOLOGIN)	

build_test:
	$(info ## build test $(VERSION) ($(BUILD_DATE)).)
	docker-compose -f docker-compose.test.yml build --build-arg RSYSLOG_VERSION --build-arg VERSION --build-arg BUILD_DATE --build-arg DISABLE_YUM_MIRROR=true --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy
	$(call docker_tag_latest)

rebuild_test: clean_test
	$(info ## re-build test $(VERSION) ($(BUILD_DATE)).)
	docker-compose -f docker-compose.test.yml build --no-cache --pull --build-arg RSYSLOG_VERSION --build-arg VERSION --build-arg BUILD_DATE --build-arg DISABLE_YUM_MIRROR=true --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy
	$(call docker_tag_latest)

clean: clean_test
	$(info ## remove $(VERSION).)
	docker rmi $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest
	#docker image prune -f --filter 'label=org.label-schema.name=rsyslog'
	#docker system prune -f --filter 'label=org.label-schema.name=rsyslog'

clean_test:
	$(info ## clean test.)
	docker-compose -f docker-compose.test.yml down -v --rmi 'local'
	docker container prune -f --filter 'label=com.docker.compose.project=docker-rsyslog'
	docker volume prune -f --filter 'label=com.docker.compose.project=docker-rsyslog'
	rm -rf test/config_check/*

# A failed test won't run the next command to clean, so clean before just in case
# Assume sudo might be used due to the security risk of adding a normal user to the docker group, so chown the config check files copied into the test dir
test: clean_test build
	$(info ## test.)
	docker-compose -f docker-compose.test.yml run sut
	if [ -n "$$SUDO_UID" -a -n "$$SUDO_GID" ]; then chown -R "$$SUDO_UID:$$SUDO_GID" test/config_check; fi
	docker-compose -f docker-compose.test.yml down -v --rmi 'local'

test_config: clean_test
	$(info ## test config.)
	docker-compose -f docker-compose.test.yml run test_syslog_server_config
	if [ -n "$$SUDO_UID" -a -n "$$SUDO_GID" ]; then chown -R "$$SUDO_UID:$$SUDO_GID" test/config_check; fi
	docker-compose -f docker-compose.test.yml down -v --rmi 'local'

#push: test
#	docker-compose -f docker-compose.yml push
