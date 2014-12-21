if (!isNil "tp_functions_defined") exitWith {};

#include "macro.h"

diag_log format["Loading tp functions ..."];

IMPORT_FINALIZER;

if (isServer) then {
  parsingNamespace setVariable ["tp_players_list", []];
};

tp_get_player_list = {
  (parsingNamespace getVariable "tp_players_list")
} call finalizer;


tp_player_list_arg = {
  ARGV2(0,_player_or_uid);

  def(_uid);
  if (isSTRING(_player_or_uid)) then {
    _uid = _player_or_uid;
  };

  if (isOBJECT(_player) && {isPlayer _player}) then {
    _uid = getPlayerUID _player;
  };
  if (!isSTRING(_uid) || {_uid == ""}) exitWith {};

  _uid
};

tp_is_player_in_list = {
  init(_uid,_this call tp_player_list_arg);
  if (isNil "_uid") exitWith {false};

  def(_list);
  _list = call tp_get_player_list;

  ((_list find _uid) >= 0)
} call finalizer;

tp_add_player_to_list = {
  init(_uid,_this call tp_player_list_arg);
  if (isNil "_uid") exitWith {};

  def(_list);
  _list = call tp_get_player_list;
  if (_uid in _list) exitWith {};

  _list pushBack _uid;
} call finalizer;

tp_remove_player_from_list = {
  init(_uid,_this call tp_player_list_arg);
  if (isNil "_uid") exitWith {false};

  def(_list);
  _list = call tp_get_player_list;

  def(_index);
  _index = _list find _uid;
  if (_index < 0) exitWith {};

  _list set [_index, ""];
} call finalizer;

tp_cleanup_player_list = {
  def(_list);
  _list = call tp_get_player_list;

  def(_index);
  while {true} do {
    _index = _list find "";
    if (_index < 0) exitWith {};
    _list deleteAt _index;
  };
};

if (isServer) then {
  tp_request_handler =  {
    if (!isServer) exitWith {};
    ARGVX3(0,_player,objNull);
    ARGVX3(1,_position,[]);
    ARGV2(2,_arg3);
    ARGV2(3,_arg4);

    if (!isPOS(_position)) exitWith {};
    if (!(isPlayer _player)) exitWith {
      diag_log format["WARNING: TP: Attempt to teleport a non-player object: %1", _player];
    };

    def(_uid);
    _uid = getPlayerUID _player;

    def(_format);
    _format = if (isSTRING(_arg3)) then {_arg3} else {"default"};

    def(_client_secret);
    _client_secret = if (isSCALAR(_arg3)) then {_arg3} else {if (isSCALAR(_arg4)) then {_arg4} else {nil}};

    if (!isSCALAR(_client_secret)) exitWith {
      diag_log format["WARNING: TP: No secret provided to teleport %1(%2)", (name  _player), _uid];
    };

   /*
    if ([_player] call tp_is_player_in_list) exitWith {
      diag_log format["WARNING: TP: Attempt to teleport %1(%2) more than once in life-time", (name _player), _uid];
    };
  */

    def(_secret);
    _secret = parsingNamespace  getVariable  (format["%1_secret", _uid]);

    if (!isSCALAR(_secret)) exitWith {
      diag_log format["WARNING: TP: Could not find a secret associated with %1(%2)", (name _player), _uid];
    };

    if (_client_secret != _secret) exitWith {
      diag_log format["WARNING: TP: Attempt to teleport %1(%2) with wrong secret",(name _player), _uid];
    };

    _format = toLower _format;

    if (_format == "default") then {
      _player setPos _position;
    }
    else { if(_format == "atl") then {
      _player setPosATL _position;
    }
    else { if (_format == "asl") then {
      _player setPosASL _position;
    }
    else { if (_format == "asl2") then {
      _player setPosASL2 _position;
    }
    else { if (_format == "aslw") then {
      _player setPosASLW _position;
    }
    else { if (_format == "world") then {
      _player setPosWorld _position;
    };};};};};};


    [_player] call tp_add_player_to_list;
    [] call tp_cleanup_player_list;

  } call finalizer;
};

serverSetPos = {
  def(_secret);
  _secret = (parsingNamespace getVariable (format["%1_secret", getPlayerUID player]));

  if (isSCALAR(_secret)) then {
    _this pushBack _secret;
  };

  if (!isNil "tp_request_handler") exitWith {
    (_this call tp_request_handler)
  };

  tp_request = _this;
  publicVariableServer "tp_request";
} call finalizer;

tp_setup = {
  if (isServer) exitWith {
    "tp_request" addPublicVariableEventHandler {(_this select 1) call serverSetPos;};
    tp_setup_complete = true;
    publicVariable "tp_setup_complete";
  };

  waitUntil {!isNil "tp_setup_complete"};
} call finalizer;

tp_set_secret = {
  ARGVX3(0,_player,objNull);
  ARGVX3(1,_secret,0);

  def(_uid);
  _uid = getPlayerUID _player;

  def(_name);
  _name = format["%1_secret", _uid];

  def(_csecret);
  _csecret = parsingNamespace getVariable _name;

  if (!isNil "_csecret") exitWith {
    diag_log format["WARNING: TP: Attempt to override %1's TP secret", _uid];
  };

  parsingNamespace setVariable [_name, _secret];

  _player addMPEventHandler ["mpkilled", {(_this select 0) call tp_remove_player_from_list}];

  false
} call finalizer;

tp_unset_secret = {
  ARGVX3(0,_uid,"");

  def(_name);
  _name = format["%1_secret", _uid];

  parsingNamespace setVariable [_name, nil];
  false
} call finalizer;


tp_secret_setup = {
  if (isServer) exitWith {
    ["TP_leave", "onPlayerDisconnected", {[_uid] call  tp_unset_secret}] call BIS_fnc_addStackedEventHandler;
    "tp_set_secret_request" addPublicVariableEventHandler { (_this select 1)  call tp_set_secret};

    tp_secret_setup_complete = true;
    publicVariable "tp_secret_setup_complete";
  };


  //client-side
  waitUntil {!isNil "tp_secret_setup_complete"};
  waitUntil {!isNull player};


  init(_secret,random 1000000);
  parsingNamespace setVariable [format["%1_secret", getPlayerUID player], _secret];
  tp_set_secret_request = [player, _secret];
  publicVariableServer "tp_set_secret_request";

} call finalizer;

[] call tp_setup;
[] call tp_secret_setup;

diag_log format["Loading tp functions completed"];
tp_functions_defined = true;