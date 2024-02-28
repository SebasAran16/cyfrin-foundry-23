-include .env

.PHONY: all test deploy

help:
	@echo "Usage: "
	@echo " make deploy [ARGS=...]"

all: clean remove install update build

#Clean the repo
clean:; forge cleam

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

build:; forge build

install:; forge install cyfrin/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit

# Update Dependencies
update:; forge update

test:; forge test

snapshot:; forge snapshot

format:; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvv

# if ---network sepolia is used, them use Sepolia args, otherwise Anvil args
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(METAMASK_TEST1_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# @ at the start of the command to hide it on the terminal once executed (to avoid displaying private keys)
deploy:
	@forge script script/DeployOurToken.s.sol:DeployOurToken $(NETWORK_ARGS)