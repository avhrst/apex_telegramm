set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_050100 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2016.08.24'
,p_default_workspace_id=>2262647084844870
);
end;
/
begin
wwv_flow_api.remove_restful_service(
 p_id=>wwv_flow_api.id(2267957667151445)
,p_name=>'telegram'
);
 
end;
/
prompt --application/restful_services/telegram
begin
wwv_flow_api.create_restful_module(
 p_id=>wwv_flow_api.id(2267957667151445)
,p_name=>'telegram'
,p_uri_prefix=>'telegram/'
,p_parsing_schema=>'BOT_PLATFORM'
,p_items_per_page=>25
,p_status=>'PUBLISHED'
,p_row_version_number=>13
);
wwv_flow_api.create_restful_template(
 p_id=>wwv_flow_api.id(2268097510151446)
,p_module_id=>wwv_flow_api.id(2267957667151445)
,p_uri_template=>'ping'
,p_priority=>0
,p_etag_type=>'HASH'
);
wwv_flow_api.create_restful_handler(
 p_id=>wwv_flow_api.id(2268150030151446)
,p_template_id=>wwv_flow_api.id(2268097510151446)
,p_source_type=>'PLSQL'
,p_format=>'DEFAULT'
,p_method=>'GET'
,p_require_https=>'YES'
,p_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE BEGIN',
'    apex_json.open_object; -- {',
'    apex_json.write(''status'',true);',
'    apex_json.close_object; -- } ',
'    :status := 200;',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        :status := 500;',
'        apex_json.open_object; -- {',
'        apex_json.write(''status'',false);',
'        apex_json.write(''msg'',substr(sqlerrm,1,4000) );',
'        apex_json.close_object; -- } ',
'END;'))
);
wwv_flow_api.create_restful_param(
 p_id=>wwv_flow_api.id(2268201141156300)
,p_handler_id=>wwv_flow_api.id(2268150030151446)
,p_name=>'X-APEX-STATUS-CODE'
,p_bind_variable_name=>'status'
,p_source_type=>'HEADER'
,p_access_method=>'OUT'
,p_param_type=>'STRING'
);
wwv_flow_api.create_restful_template(
 p_id=>wwv_flow_api.id(2268302669159665)
,p_module_id=>wwv_flow_api.id(2267957667151445)
,p_uri_template=>'webhook/{token}'
,p_priority=>0
,p_etag_type=>'HASH'
);
wwv_flow_api.create_restful_handler(
 p_id=>wwv_flow_api.id(2268416224175894)
,p_template_id=>wwv_flow_api.id(2268302669159665)
,p_source_type=>'PLSQL'
,p_format=>'DEFAULT'
,p_method=>'POST'
,p_require_https=>'YES'
,p_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'declare',
'v_body clob;',
'begin',
'v_body := telegram.blob2clob(:body);',
'telegram.in_parse(v_body);',
'end;'))
);
end;
/
begin
wwv_flow_api.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false));
commit;
end;
/
set verify on feedback on define on
prompt  ...done
