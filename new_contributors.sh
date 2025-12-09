repo="paritytech/polkadot-sdk"
since="2025-11-01" 

echo "Fetching potential new contributors (excluding org members)..."

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
  
  # Skip bots to save time and reduce noise
  if [[ "$user" == *"bot"* ]] || [[ "$user" == *"Bot"* ]]; then continue; fi

  # FIX: \033[K clears everything to the right of the cursor
  printf "\rChecking (%d/%d): %s ... \033[K" "$current" "$count" "$user"
  sleep 2

  prev_count=$(gh search prs "created:<$since" --repo "$repo" --author "$user" --json number --jq 'length' 2>/dev/null)
  
  if [[ "$prev_count" =~ ^[0-9]+$ ]]; then
    if [ "$prev_count" -eq 0 ]; then
      # Clear line fully before printing the match
      printf "\r\033[K" 
      echo "★ NEW CONTRIBUTOR: $user"
    fi
  fi
done

echo -e "\nDone."