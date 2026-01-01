#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
STORAGE_CAPACITY="10G"     # How much space to assign
ZONE_NAME="dc1"            # Physical zone name
LAYOUT_VERSION="1"         # Increment this if you change layout later
CONTAINER_NAME="garage"    # The name of your docker container

# ==========================================
# COMPATIBILITY FIX
# ==========================================
export MSYS_NO_PATHCONV=1

echo "--- Starting Garage Setup ---"

# 1. Get the Node ID and clean the output
# We use 'tail -n 1' to get the last line and 'cut' to get the part before '@'
echo "Searching for Node ID..."
FULL_ID_STRING=$(docker exec $CONTAINER_NAME /garage node id | tail -n 1)
NODE_ID=$(echo $FULL_ID_STRING | cut -d'@' -f1)

if [ -z "$NODE_ID" ] || [ ${#NODE_ID} -lt 10 ]; then
    echo "Error: Could not find a valid Node ID. Is the container running?"
    exit 1
fi

echo "Cleaned Node ID: $NODE_ID"

# 2. Assign Capacity
echo "Assigning $STORAGE_CAPACITY to zone $ZONE_NAME..."
docker exec $CONTAINER_NAME /garage layout assign \
    -z $ZONE_NAME \
    -c $STORAGE_CAPACITY \
    $NODE_ID

# 3. Apply the Layout
echo "Applying cluster layout version $LAYOUT_VERSION..."
docker exec $CONTAINER_NAME /garage layout apply --version $LAYOUT_VERSION

# 4. Show Final Status
echo "--- Final Status ---"
docker exec $CONTAINER_NAME /garage status

echo "Setup complete!"