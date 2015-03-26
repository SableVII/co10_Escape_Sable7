//waituntil{!isNil("BIS_fnc_init")};
if(!isServer) exitwith {};
["Server started."] spawn a3e_fnc_debugmsg;
if(isNil("a3e_var_commonLibInitialized")) then {
	call compile preprocessFileLineNumbers "Scripts\DRN\CommonLib\CommonLib.sqf";
};

//Parse the parameters
call a3e_fnc_parameterInit;

if(!isNil("Param_Debug")) then {
	if((Param_Debug)==0) then {
		A3E_Debug = false;
	} else {
		A3E_Debug = true;
	};
} else {
	A3E_Debug = true;
	["Warning! Debug was set to true because of missing param!."] spawn a3e_fnc_debugmsg;
};
publicVariable "A3E_Debug";


// Add crashsite here
//##############


private ["_EnemyCount","_pos","_enemyMinSkill", "_enemyMaxSkill", "_searchChopperSearchTimeMin", "_searchChopperRefuelTimeMin", "_enemySpawnDistance", "_playerGroup", "_enemyFrequency", "_comCenGuardsExist", "_fenceRotateDir", "_scriptHandle"];

// Developer Variables
EAST Setfriend [RESISTANCE, 1];
RESISTANCE setFriend [EAST, 1];

WEST setFriend [RESISTANCE, 0];
RESISTANCE setFriend [WEST, 0];


//[] spawn MB_fnc_randomWeather2;
private["_weather","_weatherTrend"];
_weather = ["clear","sunny","cloudy","foggy","bad","random"] select Param_Weather;
_weatherTrend = ["constant","worse","pWorse","better","pBetter","freeCycle","random"] select Param_WeatherTrend;

0 = [_weather, _weatherTrend, 0, [0, 0.2], 0, [0, 1, 0, 0.4, 0, 1]] execVM "Scripts\tort\tort_DynamicWeather.sqf";

private ["_hour","_date"];
_hour = Param_TimeOfDay;
_date = date;
if(_hour==24) then {
	_hour = round(random(24));
};
_date set [3,_hour];
[_date] call bis_fnc_setDate;

setTimeMultiplier Param_TimeMultiplier;
call compile preprocessFileLineNumbers ("Island\CommunicationCenterMarkers.sqf");


// Game Control Variables, do not edit!

a3e_var_Escape_AllPlayersDead = false;
a3e_var_Escape_MissionComplete = false;
publicVariable "a3e_var_Escape_AllPlayersDead";
publicVariable "a3e_var_Escape_MissionComplete";

a3e_var_GrpNumber = 0;

_enemyMinSkill = Param_EnemySkill;
_enemyMaxSkill = _enemyMinskill;
a3e_var_Escape_enemyMinSkill = _enemyMinSkill;
a3e_var_Escape_enemyMaxSkill = _enemyMaxSkill;

_searchChopperSearchTimeMin = (5 + random 10);
_searchChopperRefuelTimeMin = (5 + random 10);

_enemyFrequency = (Param_EnemyFrequency);
_enemySpawnDistance = (Param_EnemySpawnDistance);
_villagePatrolSpawnArea = (Param_VillageSpawnCount);

drn_searchAreaMarkerName = "drn_searchAreaMarker";

// Choose a start position

A3E_StartPos = [] call a3e_fnc_findFlatArea;
publicVariable "A3E_StartPos";


A3E_Var_ClearedPositions = [];
A3E_Var_ClearedPositions pushBack A3E_StartPos;
A3E_Var_ClearedPositions pushBack (getMarkerPos "drn_insurgentAirfieldMarker");

if(isNil("A3E_ClearedPositionDistance")) then {
	A3E_ClearedPositionDistance = 500;
};

// Build start position
_fenceRotateDir = random 360;
_scriptHandle = [A3E_StartPos, _fenceRotateDir] spawn a3e_fnc_BuildPrison;

A3E_FenceIsCreated = true;
publicVariable "A3E_FenceIsCreated";

//### The following is a mission function now

[true] call drn_fnc_InitVillageMarkers; 
[true] call drn_fnc_InitAquaticPatrolMarkers; 

[_enemyFrequency] call compile preprocessFileLineNumbers "Units\UnitClasses.sqf";


_playerGroup = [] call A3E_fnc_GetPlayerGroup;


[_enemyMinSkill, _enemyMaxSkill, _enemyFrequency, A3E_Debug] execVM "Scripts\Escape\EscapeSurprises.sqf";


// Initialize communication centers

[] call A3E_fnc_createComCenters;

_EnemyCount = [3] call A3E_fnc_GetEnemyCount;

[_playerGroup, "drn_CommunicationCenterPatrolMarker", east, "INS", 4, _EnemyCount select 0, _EnemyCount select 1, _enemyMinSkill, _enemyMaxSkill, _enemySpawnDistance] call drn_fnc_InitGuardedLocations;

// Initialize armor defence at communication centers


[_playerGroup, a3e_var_Escape_communicationCenterPositions, _enemySpawnDistance, _enemyFrequency] call drn_fnc_Escape_InitializeComCenArmor;



// Initialize ammo depots

[_enemyMinSkill, _enemyMaxSkill, _enemySpawnDistance, _playerGroup, _enemyFrequency] spawn {
	private ["_enemyMinSkill", "_enemyMaxSkill", "_enemySpawnDistance", "_playerGroup", "_enemyFrequency"];
	private ["_playerGroup", "_minEnemies", "_maxEnemies", "_bannedPositions", "_scriptHandle"];
	
	_enemyMinSkill = _this select 0;
	_enemyMaxSkill = _this select 1;
	_enemySpawnDistance = _this select 2;
	_playerGroup = _this select 3;
	_enemyFrequency = _this select 4;
	
	_EnemyCount = [2] call A3E_fnc_GetEnemyCount;
	_minEnemies = _EnemyCount select 0;
	_maxEnemies = _EnemyCount select 1;
	
	_bannedPositions = + a3e_var_Escape_communicationCenterPositions + [A3E_StartPos, getMarkerPos "drn_insurgentAirfieldMarker"];
	a3e_var_Escape_ammoDepotPositions = _bannedPositions call drn_fnc_Escape_FindAmmoDepotPositions;
	
	[] call A3E_fnc_createAmmoDepots;
	
	[_playerGroup, "drn_AmmoDepotPatrolMarker", east, "INS", 3, _minEnemies, _maxEnemies, _enemyMinSkill, _enemyMaxSkill, _enemySpawnDistance, A3E_Debug] spawn drn_fnc_InitGuardedLocations;
};


// Initialize search leader
[drn_searchAreaMarkerName, A3E_Debug] execVM "Scripts\Escape\SearchLeader.sqf";

// Create motorized search group

[_enemyFrequency, _enemyMinSkill, _enemyMaxSkill] spawn {
	private ["_enemyFrequency", "_enemyMinSkill", "_enemyMaxSkill"];
	private ["_spawnSegment"];
	
	_enemyFrequency = _this select 0;
	_enemyMinSkill = _this select 1;
	_enemyMaxSkill = _this select 2;
	
	_spawnSegment = [(call drn_fnc_Escape_GetPlayerGroup), 1500, 2000] call drn_fnc_Escape_FindSpawnSegment;
	while {(str _spawnSegment) == """NULL"""} do {
		_spawnSegment = [(call drn_fnc_Escape_GetPlayerGroup), 1500, 2000] call drn_fnc_Escape_FindSpawnSegment;
		sleep 1;
	};
	
	[getPos _spawnSegment, drn_searchAreaMarkerName, _enemyFrequency, _enemyMinSkill, _enemyMaxSkill,A3E_Debug] execVM "Scripts\Escape\CreateMotorizedSearchGroup.sqf";
};


// Start garbage collector
[_playerGroup, 750, A3E_Debug] spawn drn_fnc_CL_RunGarbageCollector;


// Run initialization for scripts that need the players to be gathered at the start position
[_enemyMinSkill, _enemyMaxSkill, _enemySpawnDistance, _enemyFrequency, _villagePatrolSpawnArea] spawn {
    private ["_useVillagePatrols", "_useMilitaryTraffic", "_useAmbientInfantry", "_enemyMinSkill", "_enemyMaxSkill", "_enemySpawnDistance", "_enemyFrequency"];
    private ["_fnc_OnSpawnAmbientInfantryGroup", "_fnc_OnSpawnAmbientInfantryUnit", "_scriptHandle"];
    private ["_playerGroup", "_minEnemiesPerGroup", "_maxEnemiesPerGroup", "_fnc_OnSpawnGroup"];
    
    _enemyMinSkill = _this select 0;
    _enemyMaxSkill = _this select 1;
    _enemySpawnDistance = _this select 2;
    _enemyFrequency = _this select 3;
	_villagePatrolSpawnArea = _this select 4;
    
    _playerGroup = [] call A3E_fnc_GetPlayerGroup;
    
        switch (_enemyFrequency) do
        {
            case 1: // 1-2 players
            {
                _minEnemiesPerGroup = 2;
                _maxEnemiesPerGroup = 4;
            };
            case 2: // 3-5 players
            {
                _minEnemiesPerGroup = 3;
                _maxEnemiesPerGroup = 6;
            };
            default // 6-8 players
            {
                _minEnemiesPerGroup = 4;
                _maxEnemiesPerGroup = 8;
            };
        };
        
        _fnc_OnSpawnGroup = {
            {
                _x call drn_fnc_Escape_OnSpawnGeneralSoldierUnit;
            } foreach units _this;
        };
        
       [_playerGroup, "drn_villageMarker", east, "INS", 5, _minEnemiesPerGroup, _maxEnemiesPerGroup, _enemyMinSkill, _enemyMaxSkill, _enemySpawnDistance, _villagePatrolSpawnArea, A3E_Debug] call drn_fnc_InitVillagePatrols;

        switch (_enemyFrequency) do
        {
            case 1: // 1-2 players
            {
                _minEnemiesPerGroup = 2;
                _maxEnemiesPerGroup = 4;
            };
            case 2: // 3-5 players
            {
                _minEnemiesPerGroup = 3;
                _maxEnemiesPerGroup = 6;
            };
            default // 6-8 players
            {
                _minEnemiesPerGroup = 4;
                _maxEnemiesPerGroup = 8;
            };
        };
        
        _fnc_OnSpawnGroup = {
            {
                _x call drn_fnc_Escape_OnSpawnGeneralSoldierUnit;
            } foreach units _this;
        };
        
        [(units _playerGroup) select 0, east, a3e_arr_Escape_InfantryTypes, _minEnemiesPerGroup, _maxEnemiesPerGroup, 500000, _enemyMinSkill, _enemyMaxSkill, _enemySpawnDistance + 250, _fnc_OnSpawnGroup, A3E_Debug] call drn_fnc_InitAquaticPatrols;


    
   

    // Initialize ambient infantry groups

	_fnc_OnSpawnAmbientInfantryUnit = {
		_this call drn_fnc_Escape_OnSpawnGeneralSoldierUnit;
	};
	
	_fnc_OnSpawnAmbientInfantryGroup = {
		private ["_unit", "_enemyUnit", "_i"];
		private ["_scriptHandle"];
		
		_unit = units _this select 0;
		
		while {!(isNull _unit)} do {
			_enemyUnit = _unit findNearestEnemy (getPos _unit);
			if (!(isNull _enemyUnit)) exitWith {
				
				for [{_i = (count waypoints _this) - 1}, {_i >= 0}, {_i = _i - 1}] do {
					deleteWaypoint [_this, _i];
				};
				
				_scriptHandle = [_this, drn_searchAreaMarkerName, (getPos _enemyUnit), A3E_Debug] spawn drn_fnc_searchGroup;
				_this setVariable ["drn_scriptHandle", _scriptHandle];
			};
			
			sleep 5;
		};
	};
	
	private ["_infantryTypes"];
	private ["_infantryGroupsCount", "_radius", "_groupsPerSqkm"];

	switch (_enemyFrequency) do
	{
		case 1: // 1-2 players
		{
			_minEnemiesPerGroup = 2;
			_maxEnemiesPerGroup = 4;
			_groupsPerSqkm = 1;
		};
		case 2: // 3-5 players
		{
			_minEnemiesPerGroup = 2;
			_maxEnemiesPerGroup = 8;
			_groupsPerSqkm = 1.2;
		};
		default // 6-8 players
		{
			_minEnemiesPerGroup = 2;
			_maxEnemiesPerGroup = 12;
			_groupsPerSqkm = 1.4;
		};
	};

	_radius = (_enemySpawnDistance + 500) / 1000;
	_infantryGroupsCount = round (_groupsPerSqkm * _radius * _radius * 3.141592);
	
	[_playerGroup, east, a3e_arr_Escape_InfantryTypes, _infantryGroupsCount, _enemySpawnDistance + 200, _enemySpawnDistance + 500, _minEnemiesPerGroup, _maxEnemiesPerGroup, _enemyMinSkill, _enemyMaxSkill, 750, _fnc_OnSpawnAmbientInfantryUnit, _fnc_OnSpawnAmbientInfantryGroup, A3E_Debug] spawn drn_fnc_AmbientInfantry;

    
    // Initialize the Escape military and civilian traffic
	private ["_vehiclesPerSqkm", "_radius", "_vehiclesCount", "_fnc_onSpawnCivilian", "_vehicleClasses"];
	
	// Civilian traffic
	
	switch (_enemyFrequency) do
	{
		case 1: // 1-3 players
		{
			_vehiclesPerSqkm = 1.6;
		};
		case 2: // 4-6 players
		{
			_vehiclesPerSqkm = 1.4;
		};
		default // 7-8 players
		{
			_vehiclesPerSqkm = 1.2;
		};
	};
	
	_radius = _enemySpawnDistance + 500;
	_vehiclesCount = round (_vehiclesPerSqkm * (_radius / 1000) * (_radius / 1000) * 3.141592);
	
	_fnc_onSpawnCivilian = {
		private ["_vehicle", "_crew"];
		_vehicle = _this select 0;
		_crew = _this select 1;
		//_vehiclesGroup = _result select 2;
		
		{
			{
				_x removeWeapon "ItemMap";
			} foreach _crew; // foreach crew
			
			_x addeventhandler ["killed",{
				if ((_this select 1) in (call A3E_fnc_GetPlayers)) then {
					a3e_var_Escape_SearchLeader_civilianReporting = true;
					publicVariable "a3e_var_Escape_SearchLeader_civilianReporting";
					(_this select 1) addScore -4;
					[name (_this select 1) + " has killed a civilian."] call drn_fnc_CL_ShowCommandTextAllClients;
				}
			}];
		} foreach _crew;
		
		if (random 100 < 20) then {
			private ["_index", "_weaponItem"];
			
			_index = floor random count a3e_arr_CivilianCarWeapons;
			_weaponItem = a3e_arr_CivilianCarWeapons select _index;
			
			_vehicle addWeaponCargoGlobal [_weaponItem select 0, 1];
			_vehicle addMagazineCargoGlobal [_weaponItem select 1, _weaponItem select 2];
		};
	};
	
	[_playerGroup, civilian, a3e_arr_Escape_MilitaryTraffic_CivilianVehicleClasses, _vehiclesCount, _enemySpawnDistance, _radius, 0.5, 0.5, _fnc_onSpawnCivilian, A3E_Debug] spawn drn_fnc_MilitaryTraffic;

	
	// Enemy military traffic
	
	switch (_enemyFrequency) do
	{
		case 1: // 1-3 players
		{
			_vehiclesPerSqkm = 0.6;
		};
		case 2: // 4-6 players
		{
			_vehiclesPerSqkm = 0.8;
		};
		default // 7-8 players
		{
			_vehiclesPerSqkm = 1;
		};
	};
	
	_radius = _enemySpawnDistance + 500;
	_vehiclesCount = round (_vehiclesPerSqkm * (_radius / 1000) * (_radius / 1000) * 3.141592);
	[_playerGroup, east, a3e_arr_Escape_MilitaryTraffic_EnemyVehicleClasses, _vehiclesCount, _enemySpawnDistance, _radius, _enemyMinSkill, _enemyMaxSkill, drn_fnc_Escape_TrafficSearch, A3E_Debug] spawn drn_fnc_MilitaryTraffic;

    

	private ["_areaPerRoadBlock", "_maxEnemySpawnDistanceKm", "_roadBlockCount"];
	private ["_fnc_OnSpawnInfantryGroup", "_fnc_OnSpawnMannedVehicle"];
	
	_fnc_OnSpawnInfantryGroup = {{_x call drn_fnc_Escape_OnSpawnGeneralSoldierUnit;} foreach units _this;};
	_fnc_OnSpawnMannedVehicle = {{_x call drn_fnc_Escape_OnSpawnGeneralSoldierUnit;} foreach (_this select 1);};
	
	switch (_enemyFrequency) do {
		case 1: {
			_areaPerRoadBlock = 4.19;
		};
		case 2: {
			_areaPerRoadBlock = 3.14;
		};
		default {
			_areaPerRoadBlock = 2.5;
		};
	};
	
	_maxEnemySpawnDistanceKm = (_enemySpawnDistance + 500) / 1000;
	_roadBlockCount = round ((_maxEnemySpawnDistanceKm * _maxEnemySpawnDistanceKm * 3.141592) / _areaPerRoadBlock);
	
	if (_roadBlockCount < 1) then {
		_roadBlockCount = 1;
	};
	
	[_playerGroup, east, a3e_arr_Escape_InfantryTypes, a3e_arr_Escape_RoadBlock_MannedVehicleTypes, _roadBlockCount, _enemySpawnDistance, _enemySpawnDistance + 500, 750, 300, _fnc_OnSpawnInfantryGroup, _fnc_OnSpawnMannedVehicle, A3E_Debug] spawn drn_fnc_RoadBlocks;

	//Spawn crashsites
	if(isNil("A3E_CrashSiteCountMax")) then {
		A3E_CrashSiteCountMax = 2;
	};
	_crashSiteCount = random A3E_CrashSiteCountMax;
	for [{_x=0},{_x<_crashSiteCount},{_x=_x+1}] do {
	  _pos = [] call A3E_fnc_findFlatArea;
	  [_pos] call A3E_fnc_crashSite;
	};

	
	  switch (_enemyFrequency) do
        {
            case 1: // 1-2 players
            {
                _minEnemiesPerGroup = 2;
                _maxEnemiesPerGroup = 4;
            };
            case 2: // 3-5 players
            {
                _minEnemiesPerGroup = 3;
                _maxEnemiesPerGroup = 6;
            };
            default // 6-8 players
            {
                _minEnemiesPerGroup = 4;
                _maxEnemiesPerGroup = 8;
            };
        };
	
	
	
	//Spawn mortar sites
	[] call A3E_fnc_createMortarSites;
};


// Create search chopper

private ["_scriptHandle"];
_scriptHandle = [getMarkerPos "drn_searchChopperStartPosMarker", east, drn_searchAreaMarkerName, _searchChopperSearchTimeMin, _searchChopperRefuelTimeMin, _enemyMinSkill, _enemyMaxSkill, [], A3E_Debug] execVM "Scripts\Escape\CreateSearchChopper.sqf";
waitUntil {scriptDone _scriptHandle};


// Spawn creation of start position settings
[A3E_StartPos, _enemyMinSkill, _enemyMaxSkill, _enemyFrequency, _fenceRotateDir] spawn {
    private ["_startPos", "_enemyMinSkill", "_enemyMaxSkill", "_guardsAreArmed", "_guardsExist", "_guardLivesLong", "_enemyFrequency", "_fenceRotateDir"];
    private ["_backpack","_debugAllUnits","_i", "_guard", "_guardGroup", "_marker", "_guardCount", "_guardGroups", "_unit", "_createNewGroup", "_guardPos"];
    
    _startPos = _this select 0;
    _enemyMinSkill = _this select 1;
    _enemyMaxSkill = _this select 2;
    _enemyFrequency = _this select 3;
    _fenceRotateDir = _this select 4;
	 
    // Spawn guard

    _guardPos = [_startPos, [(_startPos select 0) - 4, (_startPos select 1) + 4, 0], _fenceRotateDir] call drn_fnc_CL_RotatePosition;
	
	_backpack = "B_AssaultPack_khk" createvehicle _startPos;

	for [{_i = 0}, {_i < 5}, {_i = _i + 1}] do {
		_weapon = a3e_arr_PrisonBackpackWeapons select floor(random(count(a3e_arr_PrisonBackpackWeapons)));
		_backpack addWeaponCargoGlobal[(_weapon select 0),1];
		_backpack addMagazineCargoGlobal[(_weapon select 1),3];
	};
	
    // Spawn more guards
    _marker = createMarkerLocal ["drn_guardAreaMarker", _startPos];
    _marker setMarkerAlpha 0;
    _marker setMarkerShapeLocal "ELLIPSE";
    _marker setMarkerSizeLocal [50, 50];
    
    _guardCount = (2 + (_enemyFrequency)) + floor (random 2);

    _guardGroups = [];
    _createNewGroup = true;
    
    for [{_i = 0}, {_i < _guardCount}, {_i = _i + 1}] do {
        private ["_pos"];
        
        _pos = [_marker] call drn_fnc_CL_GetRandomMarkerPos;
        while {_pos distance _startPos < 10} do {
            _pos = [_marker] call drn_fnc_CL_GetRandomMarkerPos;
        };
        
        if (_createNewGroup) then {
            _guardGroup = createGroup RESISTANCE;
            _guardGroups set [count _guardGroups, _guardGroup];
            _createNewGroup = false;
        };
        
        //(a3e_arr_Escape_StartPositionGuardTypes select floor (random count a3e_arr_Escape_StartPositionGuardTypes)) createUnit [_pos, _guardGroup, "", (0.5), "CAPTAIN"];
        _guardGroup createUnit [(a3e_arr_Escape_StartPositionGuardTypes select floor (random count a3e_arr_Escape_StartPositionGuardTypes)), _pos, [], 0, "FORM"];
        
        if (count units _guardGroup >= 2) then {
            _createNewGroup = true;
        };
    };
    
    {
        _guardGroup = _x;
        
        _guardGroup setFormDir floor (random 360);
        
        {
            _unit = _x; //(units _guardGroup) select 0;
            _unit setUnitRank "CAPTAIN";
			_unit unlinkItem "ItemMap";
            _unit unlinkItem "ItemCompass";
            _unit unlinkItem "ItemGPS";
			_unit unlinkItem "NVGoggles_INDEP";
			
			if(random 100 < 80) then {
				removeAllPrimaryWeaponItems _unit;
				
			};
            if ((random 100 < 20) && (Param_NoNightvision==0)) then {
                _unit linkItem "NVGoggles_INDEP";
            };
            
            _unit setSkill a3e_var_Escape_enemyMinSkill;
			//[_unit, a3e_var_Escape_enemyMinSkill] call EGG_EVO_skill;
            _unit removeMagazines "Handgrenade";
            
            _unit setVehicleAmmo 0.3 + random 0.7;

        } foreach units _guardGroup;
        
        [_guardGroup, _marker] spawn drn_fnc_SearchGroup;
        
    } foreach _guardGroups;
    
    sleep 0.5;
    

    // Start thread that waits for escape to start
    [_guardGroups, _startPos] spawn {
        private ["_guardGroups", "_startPos"];
        
        _guardGroups = _this select 0;
        _startPos = _this select 1;
        
        sleep 5;
        
        while {isNil "A3E_EscapeHasStarted"} do {
            // If any member of the group is to far away from fence, then escape has started
            {
				if ((_x distance _startPos) > 25 && (_x distance _startPos) < 100) exitWith {
					A3E_EscapeHasStarted = true;
					publicVariable "A3E_EscapeHasStarted";
				};
				// If any player have picked up a weapon, escape has started
				if (count weapons _x > 0) exitWith {
					A3E_EscapeHasStarted = true;
					publicVariable "A3E_EscapeHasStarted";
				};
            } foreach call A3E_FNC_GetPlayers;
            
            sleep 1;
        };
        
        // ESCAPE HAS STARTED
        
        
        sleep (15 + random 15);
        
        {
            private ["_guardGroup"];
            
            _guardGroup = _x;
            
            {
                _guardGroup reveal _x;
            } foreach call A3E_fnc_GetPlayers;
        } foreach _guardGroups;
    };
};
