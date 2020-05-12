pragma solidity >=0.4.22 <0.7.0;
pragma experimental ABIEncoderV2;

/**
 * @title RoommatesRating
 * @dev Contract creates a rating for roommates with whom users have rented flats.
 */
contract RoommatesRating {

    mapping(address => string) private roommatesAddresses;

    mapping(string => Roommate) private roommates;
    
    string[] private roommatesLUT;
    
    mapping(string => Group) private groups;
    
    string[] private groupsLUT;
    
    GroupEvent[] private groupEvents;
    
    /*
     * Users processing functions
     */
    
    function registration(string memory roommateAlias) public returns (Status) {
        address newRoommateAddress = msg.sender;
       
        if(roommates[roommateAlias].flag == 1
            || bytes(roommatesAddresses[newRoommateAddress]).length != 0){
            return Status.ERROR;
        }

        Roommate memory newRoommate = Roommate({
            roommateAddress:newRoommateAddress, 
            roommateAlias:roommateAlias,
            numberOfReceivedRaitings:0,
            numberOfEvaluatedUsers:0,
            flag:1
        });
        roommates[roommateAlias] = newRoommate;
        roommatesAddresses[newRoommateAddress] = roommateAlias;
        
        roommatesLUT.push(roommateAlias);
        
        return Status.OK;
    }
    
    function createGroup(string memory groupName) public returns (Status) {
        address groupOwnerAddress = msg.sender;
        string memory groupOwner = roommatesAddresses[groupOwnerAddress];
        
        if(groups[groupName].flag == 1 || roommates[groupOwner].flag == 0){
            return Status.ERROR;
        }
        
        Group memory newGroup;
        newGroup.groupName=groupName;
        newGroup.groupOwner=groupOwner;
        newGroup.flag=1;
        
        groups[groupName] = newGroup;
        groupsLUT.push(groupName);
        
        groups[groupName].members[groupOwnerAddress] = GroupMemberStatus.ACTIVE;
        groups[groupName].membersAddressLUT.push(groupOwnerAddress);
        
        logGroupEvent(GroupEventType.CREATE_GROUP, groupOwnerAddress, groupOwnerAddress, groupName);
        
        return Status.OK;
    }
    
    function removeGroup(string memory groupName) public returns (Status) {
        address groupOwnerAddress = msg.sender;
        string memory requestor = roommatesAddresses[groupOwnerAddress];
        
        if(groups[groupName].flag != 1 || keccak256(abi.encodePacked(groups[groupName].groupOwner)) != keccak256(abi.encodePacked(requestor))){
           return Status.ERROR;
        }

        delete groups[groupName];
        
        int index = -1;
        for(uint i = 0 ; i < groupsLUT.length ; i ++){
            if(keccak256(abi.encodePacked(groupsLUT[i])) == keccak256(abi.encodePacked(groupName))){
                index = int(i);
                break;
            }
        }
        if(index >= 0){
            for(uint i = uint(index); i < groupsLUT.length-1; i++){
                groupsLUT[i] = groupsLUT[i+1];
            }
            delete groupsLUT[groupsLUT.length-1];
        }
        groupsLUT.pop();

        logGroupEvent(GroupEventType.DELETE_GROUP, groupOwnerAddress, groupOwnerAddress, groupName);
        return Status.OK;
    }
    
    function requestGroupMembership(string memory groupName) public returns (Status) {
        address requestorAddress = msg.sender;
        if(groups[groupName].flag != 1 
                || bytes(roommatesAddresses[requestorAddress]).length == 0
                || groups[groupName].members[requestorAddress] == GroupMemberStatus.ACTIVE
                || groups[groupName].members[requestorAddress] == GroupMemberStatus.CANDIDATE) {
            return Status.ERROR;
        }
        groups[groupName].members[requestorAddress] = GroupMemberStatus.CANDIDATE;
        groups[groupName].membersAddressLUT.push(requestorAddress);  
        return Status.OK;
    }
    
    function confirmGroupJoinRequest(string memory roommateAlias, string memory groupName) public returns (Status) {
        address requestorAddress = msg.sender;
        string memory requestor = roommatesAddresses[requestorAddress];
        address confirmingRoommateAddress = roommates[roommateAlias].roommateAddress;
        
        if(groups[groupName].flag != 1 
                || roommates[roommateAlias].flag != 1
                || keccak256(abi.encodePacked(groups[groupName].groupOwner)) != keccak256(abi.encodePacked(requestor))
                || groups[groupName].members[confirmingRoommateAddress] != GroupMemberStatus.CANDIDATE) {
            return Status.ERROR;
        }
        groups[groupName].members[confirmingRoommateAddress] = GroupMemberStatus.ACTIVE;
        logGroupEvent(GroupEventType.ACCEPT_REQUEST, requestorAddress, confirmingRoommateAddress, groupName);
        return Status.OK;
    }
    
    function addGroupMember(string memory roommateAlias, string memory groupName) public returns (Status) {
        address requestorAddress = msg.sender;
        address roommateAddress = roommates[roommateAlias].roommateAddress;
        if(groups[groupName].flag != 1 
            || roommates[roommateAlias].flag != 1
            || groups[groupName].members[requestorAddress] != GroupMemberStatus.ACTIVE
            || groups[groupName].members[roommateAddress] == GroupMemberStatus.CANDIDATE
            || groups[groupName].members[roommateAddress] == GroupMemberStatus.ACTIVE) {
            return Status.ERROR;
        }
        
        groups[groupName].members[roommateAddress] = GroupMemberStatus.ACTIVE;
        groups[groupName].membersAddressLUT.push(roommateAddress);  
        
        logGroupEvent(GroupEventType.ACCEPT_REQUEST, requestorAddress, roommateAddress, groupName);
        return Status.OK;
    }
    
    function removeGroupMember(string memory roommateAlias, string memory groupName) public returns (Status) {
        address requestorAddress = msg.sender;
        string memory requestor = roommatesAddresses[requestorAddress];
        address roommateAddress = roommates[roommateAlias].roommateAddress;
        
        if(groups[groupName].flag != 1 
                || keccak256(abi.encodePacked(groups[groupName].groupOwner)) != keccak256(abi.encodePacked(requestor))
                || keccak256(abi.encodePacked(groups[groupName].groupOwner)) == keccak256(abi.encodePacked(roommateAlias))
                || groups[groupName].members[roommateAddress] == GroupMemberStatus.EMPTY) {
            return Status.ERROR;
        }
        
        delete groups[groupName].members[roommateAddress];
        
        address[] storage membersAddressLUT = groups[groupName].membersAddressLUT;
        
        int index = -1;
        for(uint i = 0 ; i < groupsLUT.length ; i ++){
            if(keccak256(abi.encodePacked(membersAddressLUT[i])) == keccak256(abi.encodePacked(roommateAddress))){
                index = int(i);
                break;
            }
        }
        if(index >= 0){
            for(uint i = uint(index); i < groupsLUT.length-1; i++){
                membersAddressLUT[i] = membersAddressLUT[i+1];
            }
            delete membersAddressLUT[membersAddressLUT.length-1];
        }
        membersAddressLUT.pop();
        logGroupEvent(GroupEventType.REMOVE_MEMBER, requestorAddress, roommateAddress, groupName);
        return Status.OK;
    }
    
    function passGroupOwnership(string memory roommateAlias, string memory groupName) public returns (Status) {
        address requestorAddress = msg.sender;
        string memory requestor = roommatesAddresses[requestorAddress];
        address roommateAddress = roommates[roommateAlias].roommateAddress;
        
        if(groups[groupName].flag != 1 
                || keccak256(abi.encodePacked(groups[groupName].groupOwner)) != keccak256(abi.encodePacked(requestor))
                || keccak256(abi.encodePacked(groups[groupName].groupOwner)) == keccak256(abi.encodePacked(roommateAlias))
                || groups[groupName].members[roommateAddress] != GroupMemberStatus.ACTIVE) {
            return Status.ERROR;
        }
        
        groups[groupName].groupOwner = roommateAlias;
        return Status.OK;
    }
    
    function getGroups() public view returns (string[] memory) {
        return groupsLUT;
    }
    
    function getGroupMembers(string memory groupName) public view returns (string[] memory) {
        if(groups[groupName].flag != 1){
            string[] memory empty;
            return empty;
        }
        
        uint outputLength = groups[groupName].membersAddressLUT.length;

        string[] memory output = new string[](outputLength);
        uint ptr = 0;
        for(uint i = 0; i < outputLength; i++){
            if(groups[groupName].members[groups[groupName].membersAddressLUT[i]] == GroupMemberStatus.ACTIVE){
                output[ptr] = roommatesAddresses[groups[groupName].membersAddressLUT[i]];
                ptr+=1;
            }
        }
        
       return getSlice(0, ptr, output);
    }
    
    function getGroupMembershipRequests(string memory groupName) public view returns (string[] memory) {
        if(groups[groupName].flag != 1){
            string[] memory empty;
            return empty;
        }
        
        uint outputLength = groups[groupName].membersAddressLUT.length;

        string[] memory output = new string[](outputLength);
        uint ptr = 0;
        for(uint i = 0; i < outputLength; i++){
            if(groups[groupName].members[groups[groupName].membersAddressLUT[i]] == GroupMemberStatus.CANDIDATE){
                output[ptr] = roommatesAddresses[groups[groupName].membersAddressLUT[i]];
                ptr+=1;
            }
        }
        
       return getSlice(0, ptr, output);
    }
    
    function getSlice(uint begin, uint end, string[] memory array) private pure returns (string[] memory) {
        if(array.length > 0){
           string[] memory output = new string[](end-begin);
        
            for(uint i = 0 ; i < end-begin ; i++){
                output[i] = array[i+begin];
            }
            return output;    
        }
    }
    
    function logGroupEvent(GroupEventType eventType, address sourceUser, address destiantionUser, string memory groupName) private {
        GroupEvent memory groupEvent = GroupEvent({
            eventType:eventType,
            sourceUser:sourceUser,
            destiantionUser:destiantionUser,
            groupName:groupName
        });
        
        groupEvents.push(groupEvent);
    }

    /*
     * Raiting hanling  functions
     */
    function rateRoommate(string memory groupName, string memory roommateAlias, uint8 value) public returns (Status) {
        address requestorAddress = msg.sender;
        string memory requestor = roommatesAddresses[requestorAddress];
        address roommateAddress = roommates[roommateAlias].roommateAddress;
        
        if(groups[groupName].flag != 1 
                || requestorAddress == roommateAddress
                || groups[groupName].members[requestorAddress] !=  GroupMemberStatus.ACTIVE
                || groups[groupName].members[roommateAddress] !=  GroupMemberStatus.ACTIVE){
           return Status.ERROR; 
        }
        
        UserRating memory raiting = UserRating({
            value:value,
            evaluative:requestorAddress
        });
        
        uint ptr = roommates[roommateAlias].numberOfReceivedRaitings;
        roommates[roommateAlias].raitings[ptr] = raiting;
        roommates[roommateAlias].numberOfReceivedRaitings = ptr + 1;
        roommates[requestor].numberOfEvaluatedUsers = roommates[requestor].numberOfEvaluatedUsers + 1;
        return Status.OK;
    }
    
    function geRoommateRaiting(string memory roommateAlias) public view returns (uint8) {
        
        if(roommates[roommateAlias].flag != 1 || roommates[roommateAlias].numberOfReceivedRaitings == 0) {
            return 0;
        }
        
        uint acc = 0;
        for(uint i = 0 ; i < roommates[roommateAlias].numberOfReceivedRaitings ; i++){
            acc = acc + roommates[roommateAlias].raitings[i].value;
        }
        return uint8(acc / roommates[roommateAlias].numberOfReceivedRaitings);
    }
    
    /*
     * Common elements
     */
     
     struct Roommate {
         
         address roommateAddress;
         
         string roommateAlias;
         
         uint numberOfReceivedRaitings;
         
         uint numberOfEvaluatedUsers;
         
         mapping (uint => UserRating) raitings;
         
         uint8 flag;
     }
     
     struct Group {
         
         string groupName;
         
         string groupOwner;
         
         mapping (address => GroupMemberStatus) members;
         
         address[] membersAddressLUT;
         
         uint8 flag;
     }
     
     struct UserRating {
         
         uint8 value;
         
         address evaluative;
     }
     
     struct GroupEvent {
         
         GroupEventType eventType;
         
         address sourceUser;
         
         address destiantionUser;
         
         string groupName;
     }
     
     enum GroupEventType {
         ACCEPT_REQUEST, REMOVE_MEMBER, DELETE_GROUP, CREATE_GROUP
     }
     
     enum GroupMemberStatus {
         EMPTY, ACTIVE, CANDIDATE
     }
     
     enum Status {
         OK, ERROR
     }
}
