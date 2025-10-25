MAIL_HOST := 10.20.30.40
SSH_USER := root
SSH_KEY := ~/.ssh/hetzner

CONFIG_REMOTE := /mail/config
DATA_REMOTE   := /mail/data
STATE_REMOTE  := /mail/state

CONFIG_TAR := /tmp/mail_config.tar.gz
DATA_TAR   := /tmp/mail_data.tar.gz
STATE_TAR  := /tmp/mail_state.tar.gz

.PHONY: backup restore alias-create alias-delete

backup:
	ssh -i ${SSH_KEY} ${SSH_USER}@$(MAIL_HOST) sudo tar -cvz ${CONFIG_REMOTE} > ${CONFIG_TAR}
	ssh -i ${SSH_KEY} ${SSH_USER}@$(MAIL_HOST) sudo tar -cvz ${DATA_REMOTE} > ${DATA_TAR}
	ssh -i ${SSH_KEY} ${SSH_USER}@$(MAIL_HOST) sudo tar -cvz ${STATE_REMOTE} > ${STATE_TAR}

restore:
	cat $(CONFIG_TAR) | ssh -i ${SSH_KEY} ${SSH_USER}@${MAIL_HOST} sudo tar -xzf - -C /
	cat $(DATA_TAR)   | ssh -i ${SSH_KEY} ${SSH_USER}@${MAIL_HOST} sudo tar -xzf - -C /
	cat $(STATE_TAR)  | ssh -i ${SSH_KEY} ${SSH_USER}@${MAIL_HOST} sudo tar -xzf - -C /

alias-create:
	@if [ "$(words $(MAKECMDGOALS))" -ne 3 ]; then \
		echo "Usage: make alias-create <alias> <mailbox>"; \
		exit 1; \
	fi
	@alias_name=$(word 2,$(MAKECMDGOALS)); \
	mailbox=$(word 3,$(MAKECMDGOALS)); \
	ssh -i ${SSH_KEY} ${SSH_USER}@${MAIL_HOST} docker exec mail setup alias add $$alias_name@dtlp.cc $$mailbox@dtlp.cc

alias-delete:
	@if [ "$(words $(MAKECMDGOALS))" -ne 3 ]; then \
		echo "Usage: make alias-delete <alias> <mailbox>"; \
		exit 1; \
	fi
	@alias_name=$(word 2,$(MAKECMDGOALS)); \
	mailbox=$(word 3,$(MAKECMDGOALS)); \
	ssh -i ${SSH_KEY} ${SSH_USER}@${MAIL_HOST} docker exec mail setup alias del $$alias_name@dtlp.cc $$mailbox@dtlp.cc

# catch-all rule to ignore unknown targets (prevents 'No rule to make target' errors)
%:
	@:
