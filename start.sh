#!/bin/bash

# ANSI color codes and formating
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[33m'
BOLD='\033[1m'
NORMAL='\033[0m'
UNDERLINE='\033[4m'
RESET='\033[0m'
NC='\033[0m'  # No color

# Function to print text in a larger size
print_large_text() {
    echo -e "${BOLD}${BLUE}$1${NORMAL}"
}

# Function to have faucet link 
echo_clickable_link() {
    local url="$1"
    local link_text="$2"

    echo -e "${BOLD}${UNDERLINE}${link_text}${RESET}"
    echo "Click here -> ${url}"
}

# Function to print text in red
print_red() {
    echo -e "${RED}$1${NC}"
}

# Function to print text in yellow
print_yellow() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to print text in blue
print_blue() {
    echo -e "${BLUE}$1${NC}"
}

# Function to build a transaction with delegate certificate

delegate_certificate_transaction() {    
            cardano-cli conway transaction build \
            --testnet-magic 4 \
            --witness-override 2 \
            --tx-in $(cardano-cli query utxo --address $(cat payment.addr) --testnet-magic 4 --out-file  /dev/stdout | jq -r 'keys[0]') \
            --change-address $(cat payment.addr) \
            --certificate-file vote-deleg.cert \
            --out-file tx.raw

            cardano-cli conway transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file payment.skey \
            --signing-key-file stake.skey \
            --testnet-magic 4 \
            --out-file tx.signed

            cardano-cli conway transaction submit \
            --testnet-magic 4 \
            --tx-file tx.signed
}

get_last_enacted_gov_action_ID() {
    cardano-cli conway query gov-state --testnet-magic 4 | jq -r .enactState.prevGovActionIds
}


time_passing_animation() {
    local animation="|/-\\"
    local dots=""
    for _ in {1..3}; do
        for i in $(seq 0 3); do
            echo -n -e "\r[ ${animation:$i:1} ] Waiting$dots"
            sleep 0.5  # Adjust the sleep duration to control the animation speed
            dots+=".."
            if [ ${#dots} -gt 20 ]; then
                dots=""
            fi
        done
    done
    echo
}


exiting_animation() {
    local animation="|/-\\"
    local dots=""
    for _ in {1..3}; do
        for i in $(seq 0 3); do
            echo -n -e "\r[ ${animation:$i:1} ] Exiting$dots"
            sleep 0.5  # Adjust the sleep duration to control the animation speed
            dots+=".."
            if [ ${#dots} -gt 20 ]; then
                dots=""
            fi
        done
    done
    echo
}

# Function to print a loading bar
loading_bar() {
    local width=30
    local percentage=0
    local fill=""
    local empty=""

    for ((i = 0; i <= $width; i++)); do
        percentage=$((i * 100 / width))
        fill=$(printf "%0.s=" $(seq 1 $i))
        empty=$(printf "%0.s " $(seq $((i + 1)) $width))
        printf "\r[%-${width}s] %d%%" "$fill$empty" "$percentage"
        sleep 0.1  # Adjust the sleep duration to control the speed of the animation
    done
    echo
}

# Function to check the existence of a file
check_file_exists() {
    if [ -e "$1" ]; then
        return 0  # File exists
    else
        return 1  # File does not exist
    fi
}

# Function to create a wallet
create_wallet() {

    loading_bar
    echo "Wallet created!"
    # Generate payment.vkey and payment.skey
    cardano-cli conway address key-gen \
    --verification-key-file payment.vkey \
    --signing-key-file payment.skey

    # Generate stake.vkey and stake.skey
    cardano-cli conway stake-address key-gen \
    --verification-key-file stake.vkey \
    --signing-key-file stake.skey

    # Build the payment address
    cardano-cli conway address build \
    --payment-verification-key-file payment.vkey \
    --stake-verification-key-file stake.vkey \
    --out-file payment.addr \
    --testnet-magic 4

    # Build the stake address
    cardano-cli conway stake-address build \
    --stake-verification-key-file stake.vkey \
    --testnet-magic 4 \
    --out-file stake.addr

    echo "Congrats, this is your new wallet address:"
    cat payment.addr
    sleep 2
    echo -e "\nWe will have to fund this address with test ADA (or tADA)"
    echo "You will have to do this step yourself, but don't worry - it's super easy!"
    echo "Copy your address"
    cat payment.addr
        sleep 2

    echo -e "\nGo to https://sancho.network/faucet to get some tADA, paste your address in the input field and I will wait here for you"
    echo_clickable_link "https://sancho.network/faucet" "SanchoNet Faucet"

    cardano-cli conway stake-address registration-certificate \
    --stake-verification-key-file stake.vkey \
    --key-reg-deposit-amt $(cardano-cli conway query gov-state --testnet-magic 4 | jq -r .enactState.curPParams.keyDeposit) \
    --out-file registration.cert
}

# Function to register your stake-address certificate
register_stake_certificate() {
    local utxo_key
    local faucet_prompt
    
    # Check if utxo is null, repeat function if it is
    while true; do
        utxo_key=$(cardano-cli query utxo --address "$(cat payment.addr)" --testnet-magic 4 --out-file /dev/stdout | jq -r 'keys[0]')
        if [ "$utxo_key" != "null" ]; then
            break  # Continue with the function
        else
            echo "Seems like ADA has not arrived yet. Trying again?"
            read -p "Choose an option (yes/no): " faucet_prompt
            case $faucet_prompt in      
              yes)
                    #repeat function
                    time_passing_animation
                    sleep 5  # Add a delay before repeating the function
                    ;;
               no)  
                    # Exit the script to come back later
                    echo "We will continue when you are ready, see you next time."
                    exiting_animation
                    sleep 5 # Add a delay before leaving so they can ready it.
                    exit
                    ;;
                *)
                    echo "Invalid option."
                    sleep 1 # Add a small delay to allow reading of "Invalid option" before restarting the function
                    ;;
            esac        
        fi
    done

    cardano-cli conway transaction build \
    --testnet-magic 4 \
    --witness-override 2 \
    --tx-in $(cardano-cli query utxo --address $(cat payment.addr) --testnet-magic 4 --out-file  /dev/stdout | jq -r 'keys[0]') \
    --change-address $(cat payment.addr) \
    --certificate-file registration.cert \
    --out-file tx.raw

    cardano-cli conway transaction sign \
    --tx-body-file tx.raw \
    --signing-key-file payment.skey \
    --signing-key-file stake.skey \
    --testnet-magic 4 \
    --out-file tx.signed

    cardano-cli conway transaction submit \
    --testnet-magic 4 \
    --tx-file tx.signed
}

# Function to register as a DRep
register_drep() {
    cardano-cli conway governance drep key-gen \
    --verification-key-file drep.vkey \
    --signing-key-file drep.skey

    cardano-cli conway governance drep id \
    --drep-verification-key-file drep.vkey \
    --out-file drep.id

    cardano-cli conway governance drep registration-certificate \
    --drep-key-hash $(cat drep.id) \
    --key-reg-deposit-amt 0 \
    --out-file drep-register.cert

    cardano-cli conway transaction build \
    --testnet-magic 4 \
    --witness-override 2 \
    --tx-in $(cardano-cli query utxo --address $(cat payment.addr) --testnet-magic 4 --out-file  /dev/stdout | jq -r 'keys[0]') \
    --change-address $(cat payment.addr) \
    --certificate-file drep-register.cert \
    --out-file tx.raw

    cardano-cli conway transaction sign \
    --tx-body-file tx.raw \
    --signing-key-file payment.skey \
    --signing-key-file drep.skey \
    --testnet-magic 4 \
    --out-file tx.signed

    cardano-cli conway transaction submit \
    --testnet-magic 4 \
    --tx-file tx.signed
    loading_bar

    echo "You are now registered as a DRep. This is your dRep ID"
    cat drep.id
}

# Function to delegate votes to a DRep
delegate_to_drep() {
    echo "Delegate votes to a DRep"
    echo "a) Always abstain"
    echo "b) Always no confidence"
    echo "c) Delegate to a DRep"
    read -p "Choose an option (a/b/c): " delegate_option

    case $delegate_option in
        a)
            # Add code for always abstain
            echo "You have chosen to always abstain."
            cardano-cli conway stake-address vote-delegation-certificate \
            --stake-verification-key-file stake.vkey \
            --always-abstain \
            --out-file vote-deleg.cert

            delegate_certificate_transaction
            ;;
        b)
            # Add code for always no confidence
            echo "You have chosen to always vote 'no confidence.'"
            cardano-cli conway stake-address vote-delegation-certificate \
            --stake-verification-key-file stake.vkey \
            --always-no-confidence \
            --out-file vote-deleg.cert

            delegate_certificate_transaction
            ;;
        c)
            # Add code to prompt for DRep ID and delegate
            read -p "Enter the DRep ID you want to delegate to: " drep_id
            # Add code to delegate to the specified DRep
            echo "You have chosen to delegate to DRep with ID: $drep_id."

            cardano-cli conway stake-address vote-delegation-certificate \
            --stake-verification-key-file stake.vkey \
            --drep-key-hash $drep_id \
            --out-file vote-deleg.cert

            delegate_certificate_transaction
            ;;
        *)
            echo "Invalid option. Please choose a valid option (a/b/c)."
            ;;
    esac
}

# Function to generate a Committee Certificate
generate_committee_certificate() {
    # Add code here to generate a Committee Certificate
    cardano-cli conway governance committee key-gen-cold \
    --cold-verification-key-file cc-cold.vkey \
    --cold-signing-key-file cc-cold.skey

    cardano-cli conway governance committee key-hash \
    --verification-key-file cc-cold.vkey > cc-key.hash

    cat cc-key.hash

    echo "Committee Certificate generated."
}

# Function to create governance actions
create_governance_actions() {
    echo "Create Governance Actions"
    echo "a) Update Committee Action"
    echo "b) Update the Constitution"
    echo "c) Motion of No Confidence"
    echo "d) Treasury Withdrawal"
    echo "e) Info"
    read -p "Choose an option (a/b/c/d/e): " governance_option

    case $governance_option in
        a)
            # Add code for updating committee action
            echo "You have chosen to update the committee action."
            ;;
        b)
            # Add code for updating the constitution
            echo "You have chosen to update the constitution."
            ;;
        c)
            # Add code for motion of no confidence
            echo "You have chosen a motion of no confidence."
            ;;
        d)
            # Add code for treasury withdrawal
            echo "You have chosen a treasury withdrawal."
            ;;
        e)
            # Add code for info
            echo "You have chosen to get info."
            ;;
        *)
            echo "Invalid option. Please choose a valid option (a/b/c/d/e)."
            ;;
    esac
}

# Function to add new CC memeber
add_new_CC() {
    govActDeposit="$(cardano-cli conway query gov-state --testnet-magic 4 | jq -r '.enactState.curPParams.govActionDeposit')"

    # Asking the user for link of the Governance Action
    read -p "Plese provide us with link of the Governance Action: " link

    # Asking the user for the text of the Governance Action
    read -p "Please provide us with the Governance Action: " governance_text
    echo "$user_text" > text.txt

    # Asking the user for the key hash of a new CC memeber
    read -p "Plese provide us with a key hash of a new CC memeber: " CC_memeber

    # Asking the user for an expiration epoch of the new CC member
    read -p "Plese provide us with the expiration epoch of a new CC memeber: " expiration_memeber

    # Asking the user for quorum
    read -p "How many members of the committee needs to accept the proposal?" quorum

    get_last_enacted_gov_action_ID

    read -p "Is there a previous Governance Action? (yes/no): " user_choice

    if [ "$user_choice" == "yes" ]; then
        read -p "Please provide Governance Action Tx Id: " governance_action_tx_id
        read -p "Please provide Governance Action Tx Index: " governance_action_index
        command="cardano-cli conway governance action update-committee \
            --testnet \
            --governance-action-deposit ${govActDeposit} \
            --stake-verification-key-file stake.vkey \
            --proposal-anchor-url ${link} \
            --proposal-anchor-metadata-file ${governance_text} \
            --add-cc-cold-verification-key-has ${CC_memeber} \
            --epoch ${expiration_memeber} \
            --quorum ${quorum} \
            --governance-action-tx-id ${governance_action_tx_id} \
            --governance-action-index ${governacne_action_index} \
            --out-file update-committee.action"
    else
        command="cardano-cli conway governance action update-committee \
            --testnet \
            --governance-action-deposit ${govActDeposit} \
            --stake-verification-key-file stake.vkey \
            --proposal-anchor-url ${link} \
            --proposal-anchor-metadata-file ${governance_text} \
            --remove-cc-cold-verification-key-hash ${CC_memeber} \
            --quorum ${quorum} \
            --out-file update-committee.action"
    fi

    # Execute the chosen command
    eval "$command"

    # Function to submit the action needs to be added
}

# Function to remove an existing CC member
remove_CC_member() {
    govActDeposit="$(cardano-cli conway query gov-state --testnet-magic 4 | jq -r '.enactState.curPParams.govActionDeposit')"

    # Asking the user for link of the Governance Action
    read -p "Plese provide us with link of the Governance Action: " link

    # Asking the user for the text of the Governance Action
    read -p "Please provide us with the Governance Action: " governance_text
    echo "$user_text" > text.txt

    # Asking the user for the key hash of a CC memeber that is to be removed
    read -p "Plese provide us with a key hash of a CC member to be removed: " CC_memeber

    # Asking the user for quorum
    read -p "How many members of the committee needs to accept the proposal?" quorum

    get_last_enacted_gov_action_ID

    read -p "Is there a previous Governance Action? (yes/no): " user_choice

    if [ "$user_choice" == "yes" ]; then
        read -p "Please provide Governance Action Tx Id: " governance_action_tx_id
        read -p "Please provide Governance Action Tx Index: " governance_action_index
        command="cardano-cli conway governance action update-committee \
            --testnet \
            --governance-action-deposit ${govActDeposit} \
            --stake-verification-key-file stake.vkey \
            --proposal-anchor-url ${link} \
            --proposal-anchor-metadata-file ${governance_text} \
            --remove-cc-cold-verification-key-hash ${CC_memeber} \
            --quorum ${quorum} \
            --governance-action-tx-id ${governance_action_tx_id} \
            --governance-action-index ${governacne_action_index} \
            --out-file update-committee.action"
    else
        command="cardano-cli conway governance action update-committee \
            --testnet \
            --governance-action-deposit ${govActDeposit} \
            --stake-verification-key-file stake.vkey \
            --proposal-anchor-url ${link} \
            --proposal-anchor-metadata-file ${governance_text} \
            --remove-cc-cold-verification-key-hash ${CC_memeber} \
            --quorum ${quorum} \
            --out-file update-committee.action"
    fi

    # Execute the chosen command
    eval "$command"

    # Function to submit the action needs to be added
}

# Function to update committee to only change the quorum
change_quorum() {
    govActDeposit="$(cardano-cli conway query gov-state --testnet-magic 4 | jq -r '.enactState.curPParams.govActionDeposit')"

    # Asking the user for link of the Governance Action
    read -p "Plese provide us with link of the Governance Action: " link

    # Asking the user for the text of the Governance Action
    read -p "Please provide us with the Governance Action: " governance_text
    echo "$user_text" > text.txt

    # Asking the user for quorum
    read -p "How many members of the committee needs to accept the proposal?" quorum

    get_last_enacted_gov_action_ID

    read -p "Is there a previous Governance Action? (yes/no): " user_choice

    if [ "$user_choice" == "yes" ]; then
        read -p "Please provide Governance Action Tx Id: " governance_action_tx_id
        read -p "Please provide Governance Action Tx Index: " governance_action_index
        command="cardano-cli conway governance action update-committee \
            --testnet \
            --governance-action-deposit ${govActDeposit} \
            --stake-verification-key-file stake.vkey \
            --proposal-anchor-url ${link} \
            --proposal-anchor-metadata-file ${governance_text} \
            --quorum ${quorum} \
            --governance-action-tx-id ${governance_action_tx_id} \
            --governance-action-index ${governacne_action_index} \
            --out-file update-committee.action"
    else
        command="cardano-cli conway governance action update-committee \
            --testnet \
            --governance-action-deposit ${govActDeposit} \
            --stake-verification-key-file stake.vkey \
            --proposal-anchor-url ${link} \
            --proposal-anchor-metadata-file ${governance_text} \
            --quorum ${quorum} \
            --out-file update-committee.action"
    fi

    # Execute the chosen command
    eval "$command"

    # Function to submit the action needs to be added
}

# Function to update the constitution
update_constitution() {
    echo "This is the the last enacted constitution"
    cardano-cli conway query gov-state --testnet-magic 4 | jq .enactState.prevGovActionIds.pgaConstitution

    read -p "Please enter the text of your new constitution: " constitution_text
    echo "$user_text" > text.txt

    # Run b2sum on the file and save the output to a variable
    b2sum_output=$(b2sum -l 256 text.txt)
    
    # Print the b2sum output
    echo "b2sum of the constution: ${b2sum_output}"

    echo "Upload the constitution file to a URL so that everyone can read it"

    read - "Please provide the link of the constitution: " constitution_link
    wget ${constitution_link} -O constitution_link.txt

    b2sum -l 256 constitution_link.txt
    echo "b2sum of the constution you wrote here: ${b2sum_output}"
    echo "If these two same numbers are the same, you have proven to have the same constituion"
    echo "Others will be able to check with this number if you changed anything to your online document"
    echo "If you have this number will not be the same as the one submitted to the SanchoNet"

    govActDeposit="$(cardano-cli conway query gov-state --testnet-magic 4 | jq -r '.enactState.curPParams.govActionDeposit')"

    # Asking the user for quorum
    read -p "How many members of the committee needs to accept the proposal?" quorum

    get_last_enacted_gov_action_ID

    read -p "Is there a previous Governance Action? (yes/no): " user_choice

    if [ "$user_choice" == "yes" ]; then
        read -p "Please provide Governance Action Tx Id: " governance_action_tx_id
        read -p "Please provide Governance Action Tx Index: " governance_action_index
        command="cardano-cli conway governance action create-constitution \
        --testnet \
        --governance-action-deposit ${govActDeposit} \
        --stake-verification-key-file stake.vkey \
        --proposal-anchor-url ${constitution_link} \
        --proposal-anchor-metadata-hash "${b2sum_output}" \
        --constitution-anchor-url b2sum_output "${b2sum_output}" \ 
        --constitution-anchor-metadata "$(cat constitution.txt)" \
        --governance-action-tx-id ${governance_action_tx_id} \
        --governance-action-index ${governance_action_index} \
        --out-file constitution.action" # Not exactly sure what are correct inputs here - best to go over with Mike
    else
        command="cardano-cli conway governance action update-committee \
            --testnet \
            --governance-action-deposit "${govActDeposit}" \
            --stake-verification-key-file stake.vkey \
            --proposal-anchor-url "${constitution_link}" \
            --proposal-anchor-metadata-file "${b2sum_output}" \
            --quorum "${quorum}" \
            --out-file update-committee.action"
    fi

    # Execute the chosen command
    eval "$command"

    # Function to submit the action needs to be added

}

# Function to find the governance ID of your proposal
find_governance_id() {
    # Add code here to find the governance ID
    echo "You have found the governance ID of your proposal."
}

# Function to vote on actions
vote_on_actions() {
    echo "Vote on Actions"
    echo "a) Yes"
    echo "b) No"
    echo "c) Abstain"
    read -p "Choose an option (a/b/c): " vote_option

    case $vote_option in
        a)
            # Add code for voting "Yes"
            echo "You have voted 'Yes' on the action."
            ;;
        b)
            # Add code for voting "No"
            echo "You have voted 'No' on the action."
            ;;
        c)
            # Add code for abstaining
            echo "You have chosen to abstain from voting."
            ;;
        *)
            echo "Invalid option. Please choose a valid option (a/b/c)."
            ;;
    esac
}

# Function to get information
get_info() {
    echo "Here you can find different info about DReps, Governance Actions, etc"
    sleep 2
    echo "1) Check constitution"
    echo "2) Check state of all DReps"
    echo "3) Check state of individual DRep"
    echo "4) Check voting power of DReps"
    echo "5) Check state of the whole committee"
    echo "6) Check state of individual committee memeber"
    echo "7) List expired committee members"
    echo "8) List active committee members"
    echo "9) List governance actions expiring at the end of the current epoch"
    echo "10) List governance actions that were proposed in the current epoch"
    echo "11) Show governance actions sorted by the number of DRep votes"
    echo "12) Show governance actions sorted by the number of SPO votes"
    echo "13) Show governance actions sorted by the number of CC votes"
    echo "14) List actions for which a DRep key has voted"
    echo "15) List actions where a DRep has not voted yet"
    echo "16) Show the total number of 'yes', 'no', and 'abstain' votes for a given governance action ID"
    echo "17) Show the active treasury withdrawal governance actions and their current vote count"
    echo "18) Show the active 'update committee' governance actions and their current vote count"
    read -p "Choose an option from 1 to 18: " info_option

    case $info_option in
        1)
            # Code for checking constitution
            echo "You asked to see the constitution"
            cardano-cli conway query constitution --testnet-magic 4
            ;;
        2)
            # Code for checking state of all DReps
            echo "Here is information about the state of all DReps"
            cardano-cli conway query drep-state --testnet-magic 4
            ;;
        3)
            # Code for checking state of individual DRep
            read -p "Enter ID od the DRep you want to check: " drep_id
            echo "You have chosen to check DRep with ID: $drep_id."
            cardano-cli conway query drep-state --drep-key-hash $drep_id
            ;;
        4) 
            # Code for checking voting power of DReps
            echo "You have choosen to check voting power of DReps"
            cardano-cli conway query drep-stake-distribution --testnet-magic 4
            ;;
        5) 
            # Code for checking state of the whole committee
            cardano-cli conway query committee-state --testnet-magic 4
            ;;
        6) 
            # Code for checking state of an individual committee key hash
            read -p "Enter the hash od the Committee Member you want to check: " CC_hash
            echo "You have chosen to check DRep with ID: $CC_hash."
            cardano-cli conway query committee-state \
            --cold-verification-key-hash $CC_hash \
            --testnet-magic 4
            ;;
        7) 
            # Code for listing expired committee members
            echo "You choose to list expired committee members"
            cardano-cli conway query committee-state --expired --testnet-magic 4
            ;;
        8) 
            # Code for listing active committee members
            echo "You choose to list active committee members"
            cardano-cli conway query committee-state --active --testnet-magic 4
            ;;
        9) 
            # Code for lising governance actions expiring at the end of the current epoch
            echo "here is a list of all governance actions expiring at the end of current epoch"
            # Would be nice to add current epoch here too
            current_epoch=$(cardano-cli query tip --testnet-magic 4 | jq .epoch)
            echo "current epoch is:"
            cat $current_epoch
            cardano-cli conway query gov-state --testnet-magic 4 \
            | jq --argjson epoch "$current_epoch" '.proposals.psGovActionStates
            | to_entries[]
            | select(.value.expiresAfter == $epoch)'
            ;;
        10) 
            # Code for listing governance actions that were proposed in the current epoch
            echo "Here is a list of all governance actions that were proposed in the current epoch"
            current_epoch=$(cardano-cli query tip --testnet-magic 4 | jq .epoch)
            echo "BTW current epoch is:"
            cat $current_epoch
            cardano-cli conway query gov-state --testnet-magic 4 \
            | jq -r --argjson epoch "$current_epoch" '.proposals.psGovActionStates
            | to_entries[]
            | select(.value.proposedIn == $epoch)'
            ;;
        11) 
            # Code for governance actions sorted by the number of DRep votes
            echo "Here is a list of governance actions sorted by the number of DRep votes"
            cardano-cli conway query gov-state --testnet-magic 4 | jq -r '
            .proposals.psGovActionStates
            | to_entries[]
            | {govActionId: .key, type: .value.action.tag, drepVoteCount: (.value.dRepVotes | keys | length)}
            ' | jq -s 'sort_by(.voteCount) | reverse[]'
            ;;
        12)
            # Code for governance actions sorted by the number of SPO votes
            echo "Here is a list of governance actions sorted by the number of SPO votes"
            cardano-cli conway query gov-state --testnet-magic 4 | jq -r '
            .proposals.psGovActionStates
            | to_entries[]
            | {govActionId: .key, type: .value.action.tag, spoVoteCount: (.value.stakePoolVotes | keys | length)}
            ' | jq -s 'sort_by(.voteCount) | reverse[]'
            ;;
        13)
            # Code for governance actions sorted by the number of CC votes
            echo "Here is a list of governance actions sorted by the number of CC votes"
            cardano-cli conway query gov-state --testnet-magic 4 | jq -r '
            .proposals.psGovActionStates
            | to_entries[]
            | {govActionId: .key, ccVoteCount: (.value.committeeVotes | keys | length)}
            ' | jq -s 'sort_by(.voteCount) | reverse[]'
            ;;
        14) 
            # Code for listing actions for which a specific DRep key has voted
            read -p "Please enter ID of the DRep you want to check: " drep_id
            echo "You have chosen to check DRep with ID: $drep_id."
            echo "Here is a list of all actions this DRep has voted for:"
            cardano-cli conway query gov-state --testnet-magic 4 | jq -r --arg dRepKey "keyHash-$drep_id" '
            .proposals.psGovActionStates
            | to_entries[]
            | select(.value.dRepVotes[$dRepKey] != null)
            | {
                govActionId: .key,
                type: .value.action.tag,
                dRepVote: .value.dRepVotes[$dRepKey],
                expiresAfter: .value.expiresAfter,
                committeeVotesCount: (.value.committeeVotes | length),
                dRepVotesCount: (.value.dRepVotes | length),
                stakePoolVotesCount: (.value.stakePoolVotes | length)
                }
            '
            ;;
        15) 
            # Code for listing actions where a DRep has not voted yet
            read -p "Please enter ID of the DRep you want to check: " drep_id
            echo "You have chosen to check DRep with ID: $drep_id."
            echo "Here is a list of all actions this DRep has not voted for yet:"
            cardano-cli conway query gov-state --testnet-magic 4 | jq -r --arg dRepKey "keyHash-$drep_id" '
            .proposals.psGovActionStates
            | to_entries[]
            | select(.value.dRepVotes[$dRepKey] == null)
            | {
                govActionId: .key,
                type: .value.action.tag,
                expiresAfter: .value.expiresAfter,
                committeeVotesCount: (.value.committeeVotes | length),
                dRepVotesCount: (.value.dRepVotes | length),
                stakePoolVotesCount: (.value.stakePoolVotes | length)
                }
            '
            ;;
        16) 
            # Code for showing the total number of 'yes', 'no', and 'abstain' votes for a given governance action ID
            read -p "Please enter ID of governance action you want to check: " gov_id
            echo "You have chosen to check governance action with ID: $gov_id."
            echo "Here are total nubmer of votes for this governance action:"
            cardano-cli conway query gov-state --testnet-magic 4 | jq -r --arg actionId "$gov_id" '
            .proposals.psGovActionStates
            | to_entries[]
            | select(.key == $actionId)
            | { govActionId: .key,
                dRepVoteYesCount: (.value.dRepVotes | with_entries(select(.value == "VoteYes")) | length),
                dRepVoteNoCount: (.value.dRepVotes | with_entries(select(.value == "VoteNo")) | length),
                dRepAbstainCount: (.value.dRepVotes | with_entries(select(.value == "Abstain")) | length),
                stakePoolVoteYesCount: (.value.stakePoolVotes | with_entries(select(.value == "VoteYes")) | length),
                stakePoolVoteNoCount: (.value.stakePoolVotes | with_entries(select(.value == "VoteNo")) | length),
                stakePoolAbstainCount: (.value.stakePoolVotes | with_entries(select(.value == "Abstain")) | length),
                committeeVoteYesCount: (.value.committeeVotes | with_entries(select(.value == "VoteYes")) | length),
                committeeVoteNoCount: (.value.committeeVotes | with_entries(select(.value == "VoteNo")) | length),
                committeeAbstainCount: (.value.committeeVotes | with_entries(select(.value == "Abstain")) | length)
                }
            '
            ;;
        17) 
            # Code for showing the active treasury withdrawal governance actions and their current vote count
            echo "Here is the list of all active treasury withdrawal governance actions: "
            current_epoch=$(cardano-cli query tip --testnet-magic 4 | jq .epoch)

            cardano-cli conway query gov-state --testnet-magic 4 | jq -r --arg currentEpoch "$current_epoch" '
            .proposals.psGovActionStates
            | to_entries[]
            | select(.value.expiresAfter > ($currentEpoch | tonumber) and .value.action.tag == "TreasuryWithdrawals")
            | { govActionId: .key,
                type: .value.action.tag,
                expiresAfter: .value.expiresAfter,
                dRepVoteYesCount: (.value.dRepVotes | with_entries(select(.value == "VoteYes")) | length),
                dRepVoteNoCount: (.value.dRepVotes | with_entries(select(.value == "VoteNo")) | length),
                dRepAbstainCount: (.value.dRepVotes | with_entries(select(.value == "Abstain")) | length),
                committeeVoteYesCount: (.value.committeeVotes | with_entries(select(.value == "VoteYes")) | length),
                committeeVoteNoCount: (.value.committeeVotes | with_entries(select(.value == "VoteNo")) | length),
                committeeAbstainCount: (.value.committeeVotes | with_entries(select(.value == "Abstain")) | length)
                }
            ' | jq -s 'sort_by(.expiresAfter)'
            ;;
        18)
            # Code for showing the active update committee governance actions and their current vote count
            echo "Here is the list of all active update committee governance actions and their current vote count"
            current_epoch=$(cardano-cli query tip --testnet-magic 4 | jq .epoch)

            cardano-cli conway query gov-state --testnet-magic 4 | jq -r --arg currentEpoch "$current_epoch" '
            .proposals.psGovActionStates
            | to_entries[]
            | select(.value.expiresAfter > ($currentEpoch | tonumber) and .value.action.tag == "UpdateCommittee")
            | { govActionId: .key,
                type: .value.action.tag,
                expiresAfter: .value.expiresAfter,
                dRepVoteYesCount: (.value.dRepVotes | with_entries(select(.value == "VoteYes")) | length),
                dRepVoteNoCount: (.value.dRepVotes | with_entries(select(.value == "VoteNo")) | length),
                dRepAbstainCount: (.value.dRepVotes | with_entries(select(.value == "Abstain")) | length),
                stakePoolVoteYesCount: (.value.stakePoolVotes | with_entries(select(.value == "VoteYes")) | length),
                stakePoolVoteNoCount: (.value.stakePoolVotes | with_entries(select(.value == "VoteNo")) | length),
                stakePoolAbstainCount: (.value.stakePoolVotes | with_entries(select(.value == "Abstain")) | length)
                }
            ' | jq -s 'sort_by(.expiresAfter)'
            ;;
        *)
            echo "Invalid option. Please choose a valid option between 1 to 18."
            ;;
    esac
}

# Start of the script

print_yellow "
                                              SANCHONET WIZARD
                                        
                                        Welcome to world of governance 

                                                :-.       ...                                       
                                            -@@@#+.            .                                    
                                           =@#*=..               ::                                 
                                          =@*     -.                .                               
                                         -@%-     *@*=-   -+##+:                                    
                                        :%@-      -*@. +**###%%#+-.                                 
                                        #@*.      .-*@        :%@#+=.                               
                                       -@#:         .+%         +@@#+-.                             
                                      .%@=             .          =%%#+-    .                       
                                      =@@=             .            .#%#=:....                      
                                      %@@-       :*%#+=-               -##*---                      
                                     :@@%-          .=+#.                .+@%--                     
                                     #@@#-             :++                 *@*+                     
                                     @@@%+.             .-*-                #@#                     
                                    .@@@@#:               :+-                @@                     
                                    :@@@@#+                :=.               .%                     
                                    :@@@@%*:                .-                :                     
                                    :@@@%#+-                .=-                                     
                                   =@@@@@#++.               .-#=                                    
                               :=%@@@@@@@%*+:             .:+*#+.                                   
                          :+#@@@@@@@@@@@@@*+=.          .:=+=:   :-                                 
                     =+%@@@@@@@@@@@@@@@@@@%*+-......:-===-:       ::                                
                +#@@@@@@@@@@@@@@%%%%####***###+=--:::.                 .                            
            =#@@@@@@@@@@%%##***++==---::.                          .:---=-=#%%@@@@@@@@@#=           
         :%@@@@@@@%###***++====---:::..                          :::=+#@@@@@@@@@@@@@@@@@@@%.        
        *@@@@@@##***+=--:::::::::...                        .. .:-#%@@@@@@@@@@@@@@@@@@@@@@@@-       
       *@@@@%#**+=--:......                                .:=+%@@@@@@@@@@@@@@@@@@@@@@@@@@@@#.      
      =@@@@**+=-::...    .                             .:-=+%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+      
      +@@@#*+--:..   .                            ..:-=*%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%.      
       =@@#+=-::.....    .....              .:---=+*%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@%:       
        :%%#+=--::..............         ..=#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%         
          .@@#+--:::........::.......:=++*%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@:           
              :+*+++=++====---+*+*%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+               
                                 *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#:                   
                                     .*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%*:                          
                                           .=%@@@@@@@@@@@@@%%#+-.                                                                                                                              
"

echo "Hello and welcome to SanchoNet Wizard. Let's give you a quick start guide, shall we?"
# We might write some text here to explain what the wizard do and what is SanchoNet. Learning while doind
sleep 2
echo "Let's see if you already have a wallet"
time_passing_animation

# Check if wallet and DRep registration files exist
if check_file_exists "payment.skey" && check_file_exists "payment.vkey"; then
    if check_file_exists "drep.id"; then
        echo "Wallet found"
        sleep 2
        echo "dRep ID found"
        sleep 2
        echo "Seems like you are familiar with SanchoNet already!"
        sleep 2
        echo "What would you like to do?"
    else
        echo "Wallet found, but you are not registered as a DRep."
        sleep 2
        echo "Let's register you as a DRep"
        register_drep
    fi
else
    echo "Seems like this is your first time here"
    sleep 2
    echo "To do anything on SanchoNet we need to create a wallet first. Let's start with that"
    sleep 2
    create_wallet
    sleep 2
    echo "Let's wait for a while for funds to arrive in our wallet"
    register_stake_certificate
fi

# Main menu
while true; do
    echo "Main Menu"
    echo "1) Delegate votes to a DRep"
    echo "2) Generate Committee Certificate"
    echo "3) Create Governance Actions"
    echo "4) Find Governance ID of your proposal"
    echo "5) Vote on Actions"
    echo "6) Informations"
    echo "0) Quit"
    read -p "Choose an option (0-6): " main_option

    case $main_option in
        1)
            delegate_to_drep
            ;;
        2)
            generate_committee_certificate
            ;;
        3)
            create_governance_actions
            ;;
        4)
            find_governance_id
            ;;
        5)
            vote_on_actions
            ;;
        6)  
            get_info
            ;;
        0)
            echo "Thank you being part of SanchoNet and helping us with governance on Cardano! Have a wonderful day!"
            exit 0
            ;;
        *)
            print_red "Invalid option. Please choose a valid option (0-5)."
            ;;
    esac
done
