#!/bin/bash

# Making sure the script stops if any of the commands fails
set -eu

# Enable debug mode if RUNNER_DEBUG is 1
[[ "${RUNNER_DEBUG:-0}" -eq 1 ]] && set -x

# Function to get visibility of the repository, whether public or private
get_repo_visibility() {
  gh repo view "$GITHUB_REPOSITORY" --json visibility \
         --jq '.visibility'
}

# Function to get the owner type of the repository, User or Organization
get_owner_type() {
  gh api -H "Accept: application/vnd.github+json" \
         -H "X-GITHUB-API-VERSION: 2022-11-28" \
         /users/"$GITHUB_REPOSITORY_OWNER" \
         --jq '.type'
}

# Function to construct the billing endpoint URL based on if the repository is owned by User or an Organization
get_billing_endpoint() {
  local owner_type="$1"
  local endpoint

  if [ "$owner_type" = "User" ]; then
    endpoint="/users/$GITHUB_REPOSITORY_OWNER/settings/billing/actions"
  elif [ "$owner_type" = "Organization" ]; then
    endpoint="/orgs/$GITHUB_REPOSITORY_OWNER/settings/billing/actions"
  fi

  echo "$endpoint"
}

# Function to fetch billing information from the constructed endpoint URL
get_billing_info() {
  local endpoint
  endpoint=$(get_billing_endpoint "$(get_owner_type)")

  gh api -H "Accept: application/vnd.github+json" \
           -H "X-GITHUB-API-VERSION: 2022-11-28" \
           "$endpoint"
}

# Function to parse total minutes being used from the billing info
get_total_minutes_used() {
  local billing_info
  billing_info=$(get_billing_info)
  echo "$billing_info" | jq -r ".total_minutes_used"
}

# Function to parse included minutes from the billing info
get_included_minutes() {
  local billing_info
  billing_info=$(get_billing_info)
  echo "$billing_info" | jq -r ".included_minutes"
}

# Function to calculate usage percentage (total minutes used / included minutes * 100)
calculate_usage_percentage() {
  local total_minutes_used
  local included_minutes

  total_minutes_used=$(get_total_minutes_used)
  included_minutes=$(get_included_minutes)

  awk -v num1="$total_minutes_used" -v num2="$included_minutes" 'BEGIN {printf "%.2f", (num1*100)/num2}'
}

# Function to monitor the usage and cancel the run if it exceeds certain threshold
monitor_usage_and_cancel_run_if_exceeded() {
  local visibility threshold percentage_used

  visibility=$(get_repo_visibility)
  if [ "$visibility" = "PUBLIC" ]; then
    echo -e "\033[1;33mGiven it's a public repo, skipping both usage tracking and action termination.\033[0m"
    return 0
  fi

  percentage_used=$(calculate_usage_percentage)
  echo -e "\033[1;34mThe current total usage is ${percentage_used}%.\033[0m"

  threshold="$INPUT_THRESHOLD"
  if [ "$(echo "$percentage_used >= $threshold" | bc -l)" -eq "1" ]; then
    echo -e "\033[1;The usage exceeds the given threshold of ${threshold}%.\033[0m"
    echo -e "\033[1;33mThe ongoing GitHub Action is being cancelled due to overuse...\033[0m"
    gh run cancel "$GITHUB_RUN_ID" --repo "$GITHUB_REPOSITORY"
  else
    echo -e "\033[1;32mThe usage is below the given threshold of ${threshold}%.\033[0m"
  fi
}

# Trimming white spaces from input token
INPUT_TOKEN=$(echo "$INPUT_TOKEN" | xargs)

# Checking the validity of provided token
if ! echo "$INPUT_TOKEN" | grep -qE "^(gh[ps]_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59})$"; then
  echo -e "\\033[1;31mError: 'token' input does not appear to be a valid GitHub token.\\033[0m"
  exit 1
fi

# Checking if the threshold is a number between 1 and 100
if [[ $INPUT_THRESHOLD -lt 1 || $INPUT_THRESHOLD -gt 100 ]]; then
  echo -e "\033[1;31mError: 'threshold' input is invalid. It must be a number between 1 and 100.\033[0m"
  exit 1
fi

# Authenticates GitHub CLI using a supplied token
echo "${INPUT_TOKEN}" | gh auth login --with-token

# Call the usage monitoring function
monitor_usage_and_cancel_run_if_exceeded
