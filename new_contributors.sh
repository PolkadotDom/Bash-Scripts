repo="paritytech/polkadot-sdk"
since="2025-11-01" 

echo "Fetching potential new contributors (excluding org members)..."

# 1. Get authors (filtering out MEMBER/OWNER)
authors=$(gh search prs --repo $repo "updated:>=$since" \
  --limit 1000 \
  --json author,createdAt,closedAt,state,authorAssociation \
  --jq ".[] | select(.authorAssociation != \"MEMBER\" and .authorAssociation != \"OWNER\") | select(.createdAt >= \"$since\" or (.state == \"MERGED\" and .closedAt >= \"$since\")) | .author.login" | sort -u)

if [ -z "$authors" ]; then
  echo "No external authors found."
  exit 0
fi

count=$(echo "$authors" | wc -w | xargs)
echo "Checking $count external authors for first-time status..."

current=0
for user in $authors; do
  current=$((current+1))
  
  printf "Checking (%d/%d): %s ... \r" "$current" "$count" "$user"
  sleep 2

  # FIX: Use explicit flags (--repo, --author) instead of a query string
  # Only the date filter remains as a positional search argument
  prev_count=$(gh search prs "created:<$since" --repo "$repo" --author "$user" --json number --jq 'length')
  
  if [[ "$prev_count" =~ ^[0-9]+$ ]]; then
    if [ "$prev_count" -eq 0 ]; then
      printf "\033[2K\r" 
      echo "★ NEW CONTRIBUTOR: $user"
    fi
  fi
done

echo -e "\nDone."