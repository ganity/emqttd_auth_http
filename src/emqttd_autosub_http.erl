%%--------------------------------------------------------------------
%% Copyright (c) 2012-2016 Feng Lee <feng@emqtt.io>.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

%% @doc Auto subscribe with http.
-module(emqttd_autosub_http).

-include("../../../include/emqttd.hrl").
-include("../../../include/emqttd_protocol.hrl").
-include("emqttd_auth_http.hrl").
-import(emqttd_auth_http, [http_request/3, feedvar/2]).

-export([load/0, unload/0]).

-export([on_client_connected/3, on_client_disconnected/3, on_client_subscribe_after/3]).

-define(APP, emqttd_auth_http).

-define(UNDEFINED(S), (S =:= undefined orelse S =:= <<>>)).

%% Called when the plugin loaded
load() ->
  Subquery = application:get_env(?APP, sub_req, undefined),
  DisconnectReq = application:get_env(?APP, offline_req, undefined),
  AfterSubReq = application:get_env(?APP, after_sub_req, undefined),

  lager:info("== subquery: ~p DisconnectReq: ~p", [Subquery, DisconnectReq]),
  emqttd:hook('client.connected', fun ?MODULE:on_client_connected/3, [record(Subquery)]),
  emqttd:hook('client.disconnected', fun ?MODULE:on_client_disconnected/3, [record(DisconnectReq)]),
  emqttd:hook('client.subscribe.after', fun ?MODULE:on_client_subscribe_after/3, [record(AfterSubReq)]).

on_client_connected(?CONNACK_ACCEPT, Client = #mqtt_client{client_pid = ClientPid}, #http_request{method = Method, url = Url, params = Params}) ->
  case http_request(Method, Url, feedvar(Params, Client)) of
    {ok, 200, Body}  -> lager:info("Body: ~s", [Body]),
      %%自动订阅
      subscribe(Body, ClientPid),
      ok;
    {ok, Code, _Body} -> {error, {http_code, Code}};
    {error, Error}     -> lager:error("HTTP ~s Error: ~p", [Url, Error]), {error, Error}
  end.

on_client_disconnected(Reason, Clientid, #http_request{method = Method, url = Url, params = Params}) ->
  lager:info("== dis connected : ~p, url: ~p, Method: ~p, params: ~p Client: ~p", [Reason, Url, Method, Params, Clientid]),
  case http_request(Method, Url, param(Params, Clientid)) of
    {ok, 200, _Body}  -> ok;
    {ok, Code, _Body} -> {error, {http_code, Code}};
    {error, Error}     -> lager:error("HTTP ~s Error: ~p", [Url, Error]), {error, Error}
  end.

%%自动订阅完成后,发送离线消息
on_client_subscribe_after(ClientId, TopicTable, #http_request{method = Method, url = Url, params = Params}) ->
  lager:info("client ~s subscribed ~p", [ClientId, TopicTable]),
  case topictable2topics(TopicTable, []) of
    [] -> ok;
    Acc -> case http_request(Method, Url, param2(Params, ClientId, Acc)) of
             {ok, 200, _Body}  -> ok;
             {ok, Code, _Body} -> {error, {http_code, Code}};
             {error, Error}     -> lager:error("HTTP ~s Error: ~p", [Url, Error]), {error, Error}
           end
  end.

%%  io:format("client ~s subscribed ~p~n", [ClientId, TopicTable]),
%%  {ok, TopicTable}.

%%
%%on_client_connected(_ConnAck, _Client, _LoadCmd) ->
%%    ok.
subscribe([], _ClientPid) ->
    ok;
subscribe(Rows, ClientPid) ->
%%  lager:info("== Rows: ~p, ClientPid: ~p", [Rows, ClientPid]),
  topics(Rows),
  emqttd_client:subscribe(ClientPid, topics(Rows)).


unload() ->
  emqttd:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
  emqttd:unhook('client.connected', fun ?MODULE:on_client_connected/3),
  emqttd:unhook('client.subscribe.after', fun ?MODULE:on_client_subscribe_after/3).

%%--------------------------------------------------------------------
%% Internel Functions
%%--------------------------------------------------------------------

param(Params, ClientId) ->
  lists:map(fun ({Param, "%c"}) -> {Param, ClientId};
                 (Param)        -> Param
            end, Params).
param2(Params, ClientId, Acc) ->
  lists:map(fun ({Param, "%c"}) -> {Param, ClientId};
                ({Param, "%o"}) -> {Param, Acc};
                (Param)        -> Param
            end, Params).

topictable2topics([], Acc) ->
%%  io:format(" Acc ~p~n", [Acc]),
  Acc;
topictable2topics([{Topic, _Qos }| Table], Acc) ->
  topictable2topics(Table, string:concat(string:concat(Acc, ","), binary_to_list(Topic))).

record(undefined) ->
  undefined;
record(Config) ->
  Method = proplists:get_value(method, Config, post),
  Url    = proplists:get_value(url, Config),
  Params = proplists:get_value(params, Config),
  #http_request{method = Method, url = Url, params = Params}.


topics(Values) ->
  Topics = string:tokens(Values, ";"),
%%  lager:info("== Values1: ~p", [Topics]),
  topics(Topics, []).
topics([], Acc) ->
  Acc;
topics([TopicQos | Vals], Acc) ->
  [Topic, Qos] = string:tokens(TopicQos, ","),
%%  lager:info("== Vals: ~p, Topic: ~p, Qos: ~p", [Vals, Topic, Qos]),
  topics(Vals, [{list_to_binary(Topic), i(Qos)}|Acc]).

i(S) -> list_to_integer(S).

