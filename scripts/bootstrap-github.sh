#!/bin/bash

# Required vars
GITHUB_USERNAME=$GITHUB_USERNAME
GITHUB_TOKEN=$GITHUB_TOKEN

# Required for local run
REPO_NAME=${REPO_NAME:-$CI_PROJECT_NAME}
GITLAB_TOKEN=${GITLAB_TOKEN:-$CI_JOB_TOKEN}
PROJECT_ID=${PROJECT_ID:-$CI_PROJECT_ID}

# Optional vars
BRANCH_NAME=${BRANCH_NAME:-main}

# GitHub API URLs
GITHUB_API_URL="https://api.github.com"
REPO_URL="$GITHUB_API_URL/user/repos"
PAGES_URL="$GITHUB_API_URL/repos/$GITHUB_USERNAME/$REPO_NAME/pages"

# Function to check if the repository exists
check_repo_exists() {
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_API_URL/repos/$GITHUB_USERNAME/$REPO_NAME")
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if mirror was already set up
check_mirror_exists() {
    response=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "https://gitlab.com/api/v4/projects/$PROJECT_ID/remote_mirrors")
    if [ "$response" = "[]" ]; then
        return 1
    else
        return 0
    fi
}

# Function to create the repository
create_repo() {
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        $REPO_URL \
        -d "{\"name\": \"$REPO_NAME\", \"auto_init\": \"false\"")

    if [ "$response" -eq 201 ]; then
        echo "✅ Repository $REPO_NAME created successfully."
    else
        echo "Failed to create repository."
        exit 1
    fi
}

# Function to set up mirror from GitLab to GitHub
setup_mirror() {
    # Construct the mirror URL
    mirror_url="https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$REPO_NAME.git"

    # Construct the JSON payload using jq
    json_payload=$(jq -n --arg url "$mirror_url" '{"url": $url, "enabled": true}')

    # Update the GitLab project to enable mirroring
    response=$(curl -s -w "%{http_code}" -o /tmp/response_body.json -X POST \
        --header "Content-Type: application/json" \
        --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        --data "$json_payload" \
        "https://gitlab.com/api/v4/projects/$PROJECT_ID/remote_mirrors")

    if [ "$response" = "201" ]; then
        echo "✅ Mirror set up from GitLab to GitHub successfully..."
        response_body=$(cat /tmp/response_body.json)
        id=$(echo "$response_body" | jq -r '.id')
        echo "Forcing push..."
        response=$(curl -s -o /dev/null -w "%{http_code}" --request POST \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            "https://gitlab.com/api/v4/projects/$PROJECT_ID/remote_mirrors/$id/sync")
        if [ "$response" = "204" ]; then
            echo "✅ Force push was done, waiting 5 seconds for push to complete..."
            sleep 5
        else
            echo "Force push has failed"
        fi
    else
        echo "Failed to set up mirror."
        exit 1
    fi
}

# Main script execution
if check_repo_exists; then
    echo "🧿 Repository $REPO_NAME does exist"
else
    echo "Repository $REPO_NAME does not exist, creating..."
    create_repo
fi

if check_mirror_exists; then
    echo "🧿 Mirror to Github already exist"
else
    echo "Mirror to Github does not exists, creating..."
    setup_mirror
fi
