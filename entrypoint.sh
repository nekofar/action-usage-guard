#!/bin/bash

set -eu

get_repo_visibility() {
  gh repo view "$GITHUB_REPOSITORY" --json visibility \
         --jq '.visibility'
}

get_owner_type() {
  gh api -H "Accept: application/vnd.github+json" \
         -H "X-GITHUB-API-VERSION: 2022-11-28" \
         /users/"$GITHUB_REPOSITORY_OWNER" \
         --jq '.type'
}

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

get_billing_info() {
  local endpoint
  endpoint=$(get_billing_endpoint "$(get_owner_type)")

  gh api -H "Accept: application/vnd.github+json" \
           -H "X-GITHUB-API-VERSION: 2022-11-28" \
           "$endpoint"
}

get_total_minutes_used() {
  local billing_info
  billing_info=$(get_billing_info)
  echo "$billing_info" | jq -r ".total_minutes_used"
}

get_included_minutes() {
  local billing_info
  billing_info=$(get_billing_info)
  echo "$billing_info" | jq -r ".included_minutes"
}

calculate_usage_percentage() {
  local total_minutes_used
  local included_minutes

  total_minutes_used=$(get_total_minutes_used)
  included_minutes=$(get_included_minutes)

  # use expr for arithmetic in bash 3.2
  # shellcheck disable=SC2003
  expr 100 \* "$total_minutes_used" / "$included_minutes"
}

monitor_usage_and_cancel_run_if_exceeded() {
  local visibility threshold percentage_used

  visibility=$(get_repo_visibility)
  threshold="$INPUT_THRESHOLD"
  percentage_used=$(calculate_usage_percentage)

  if [ "$visibility" = "PUBLIC" ]; then
    echo -e "\033[1;33mThis is a public repository. Monitoring of usage and action cancellation is skipped.\033[0m\n"
    return 0
  fi

  echo -e "\033[1;34mThe current total usage is ${percentage_used}%.\033[0m\n"

  if [ "$percentage_used" -ge "${threshold}" ]; then
    echo -e "\033[1;31mWarning: The usage exceeds the given threshold of ${threshold}%.\033[0m\n"
    echo -e "\033[1;33mThe ongoing GitHub Action is being cancelled due to overuse...\033[0m\n"
    gh run cancel "$GITHUB_RUN_ID" --repo "$GITHUB_REPOSITORY"
  else
    echo -e "\033[1;32mGood news: The usage is below the given threshold of ${threshold}%.\033[0m\n"
  fi
}

if ! echo "$INPUT_TOKEN" | grep -qE "^(gh[ps]_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59})$"; then
  echo -e "\\033[1;31mError: 'token' input does not appear to be a valid GitHub token.\\033[0m"
  exit 1
fi

if [[ $INPUT_THRESHOLD -lt 1 || $INPUT_THRESHOLD -gt 100 ]]; then
  echo -e "\033[1;31mError: 'threshold' input is invalid. It must be a number between 1 and 100.\033[0m\n"
  exit 1
fi

export GITHUB_TOKEN=${INPUT_TOKEN:-"GITHUB_TOKEN"}

monitor_usage_and_cancel_run_if_exceeded
