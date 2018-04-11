CREATE TABLE  "BOT_ERR_JOURN" 
   (	"CRT" DATE, 
	"METOD" VARCHAR2(50), 
	"ERR_MSG" CLOB
   )
/
CREATE TABLE  "BOT_JOURN" 
   (	"CRT" DATE, 
	"CHAT_ID" NUMBER, 
	"METOD" VARCHAR2(20), 
	"BODY" CLOB, 
	"RESULT" CLOB, 
	"TOKEN" VARCHAR2(200)
   )
/
CREATE TABLE  "BOT_USERS" 
   (	"CHAT_ID" NUMBER NOT NULL ENABLE, 
	"FIRST_NAME" VARCHAR2(100), 
	"LAST_NAME" VARCHAR2(100), 
	"PHONE" VARCHAR2(50), 
	"CRT" DATE, 
	"LOGIN" VARCHAR2(50), 
	"MDF" DATE, 
	"PIN" NUMBER, 
	 CONSTRAINT "BOT_USERS_PK" PRIMARY KEY ("CHAT_ID") ENABLE
   )
/
CREATE TABLE  "BOT_SESSIONS" 
   (	"CHAT_ID" NUMBER NOT NULL ENABLE, 
	"TEXT" CLOB, 
	"MDF" DATE, 
	"ST" NUMBER(1,0), 
	"MENU" VARCHAR2(20), 
	 CONSTRAINT "BOT_SESSIONS_PK" PRIMARY KEY ("CHAT_ID") ENABLE
   )
/
CREATE GLOBAL TEMPORARY TABLE  "REPLY_MARKUP_INLINE_KEYBOARD" 
   (	"TEXT" VARCHAR2(255) NOT NULL ENABLE, 
	"CALLBACK_DATA" VARCHAR2(255) NOT NULL ENABLE, 
	 CONSTRAINT "REPLY_INLINE_UK1" UNIQUE ("CALLBACK_DATA") ENABLE
   ) ON COMMIT DELETE ROWS
/
CREATE GLOBAL TEMPORARY TABLE  "REPLY_MARKUP_KEYBOARD" 
   (	"TEXT" VARCHAR2(255) NOT NULL ENABLE, 
	"REQUEST_CONTACT" NUMBER(1,0) DEFAULT 0, 
	"REQUEST_LOCATION" NUMBER(1,0), 
	 CONSTRAINT "REPLY_MARKUP_KEYBOARD_PK" PRIMARY KEY ("TEXT") ENABLE
   ) ON COMMIT DELETE ROWS
/
ALTER TABLE  "BOT_SESSIONS" ADD CONSTRAINT "BOT_SESSIONS_FK1" FOREIGN KEY ("CHAT_ID")
	  REFERENCES  "BOT_USERS" ("CHAT_ID") ON DELETE CASCADE ENABLE
/
CREATE UNIQUE INDEX  "BOT_SESSIONS_PK" ON  "BOT_SESSIONS" ("CHAT_ID")
/
CREATE UNIQUE INDEX  "BOT_USERS_PK" ON  "BOT_USERS" ("CHAT_ID")
/
CREATE UNIQUE INDEX  "REPLY_INLINE_UK1" ON  "REPLY_MARKUP_INLINE_KEYBOARD" ("CALLBACK_DATA")
/
CREATE UNIQUE INDEX  "REPLY_MARKUP_KEYBOARD_PK" ON  "REPLY_MARKUP_KEYBOARD" ("TEXT")
/
CREATE OR REPLACE PACKAGE  "TELEGRAM" AS 
    v_err_msg CLOB; 
    p_url CLOB := 'https://api.telegram.org/bot'; 
    p_token VARCHAR(200) := '<bot token>'; 
    p_debug INT := 1;  

    -- параметры входящего сообщения --  
    in_chat_id INT; 
    in_message_id INT; 
    in_text VARCHAR2(32000); 
    in_phone_number VARCHAR2(100); 
    in_first_name VARCHAR2(100); 
    in_last_name VARCHAR2(100); 
    -- callback -- 
    in_data VARCHAR2(1024); 
    -- параметры сессиии -- 
    session_st INT; -- текущее значение шага --  
    session_menu VARCHAR2(100); -- текущее значение меню --  

    ------------------------  
    FUNCTION blob2clob ( 
        p_blob        IN BLOB, 
        p_blob_csid   IN INTEGER DEFAULT dbms_lob.default_csid 
    ) RETURN CLOB;  

  -- отправка сообщения --  

    PROCEDURE sendmessage ( 
        p_chat_id             INT DEFAULT in_chat_id, 
        p_text                IN CLOB, 
        p_parse_mode          IN VARCHAR DEFAULT 'HTML', 
        p_resize_keyboard     IN BOOLEAN DEFAULT true, 
        p_one_time_keyboard   IN BOOLEAN DEFAULT true, 
        p_buttons_colum       IN INT DEFAULT 2 
    );  
-- редактировать сообщение -- 

    PROCEDURE editmessage ( 
        p_chat_id      INT DEFAULT in_chat_id, 
        p_message_id   INT DEFAULT in_message_id, 
        p_text                IN CLOB, 
        p_parse_mode          IN VARCHAR DEFAULT 'HTML', 
        p_resize_keyboard     IN BOOLEAN DEFAULT true, 
        p_one_time_keyboard   IN BOOLEAN DEFAULT true, 
        p_buttons_colum       IN INT DEFAULT 2 
    );  


  -- настройка webhook для входящих сообщений --  

    PROCEDURE setwebhook ( 
        p_webhook_url IN VARCHAR 
    );  

-- разбор входящего сообщения --  

    PROCEDURE in_parse ( 
        p_body CLOB 
    );  

-- проверка и регистрация пользователя --  

    PROCEDURE check_user ( 
        v_ex OUT NUMBER 
    );  

-- сброс счетчика шагов --  

    PROCEDURE reset_st ( 
        p_chat_id IN INT DEFAULT in_chat_id 
    );  
-- запись сесии --   

    PROCEDURE save_session ( 
        v_menu   IN VARCHAR2 DEFAULT NULL, 
        v_st     IN INT DEFAULT 0 
    );  
--   получение сесии --  

    PROCEDURE get_session; 

    -- авторизация пользователя через телеграм -- 

    PROCEDURE auth_pin ( 
        v_username IN VARCHAR2 
    ); 
    -- сообщение о входе в приложение -- 

    PROCEDURE auth_reg ( 
        v_username   IN VARCHAR2, 
        v_app_name   IN VARCHAR2 
    ); 

END telegram;
/
CREATE OR REPLACE PACKAGE BODY  "TELEGRAM" AS

    PROCEDURE add_journ (
        v_body      IN CLOB DEFAULT NULL,
        v_result    IN CLOB DEFAULT NULL,
        v_chat_id   IN NUMBER DEFAULT NULL,
        v_metod     IN VARCHAR2 DEFAULT NULL
    )
        AS
    BEGIN
        INSERT INTO bot_journ (
            crt,
            chat_id,
            metod,
            body,
            result,
            token
        ) VALUES (
            SYSDATE,
            v_chat_id,
            v_metod,
            v_body,
            v_result,
            telegram.p_token
        );

    END add_journ;  
    -- подготовка номера телефона -- 

    FUNCTION clr_phone (
        v_phone IN VARCHAR2
    ) RETURN VARCHAR2 AS
        v_res   VARCHAR2(30);
    BEGIN
        IF
            v_phone IS NULL
        THEN
            RETURN NULL;
        END IF;
        v_res := replace(v_phone,'(','');
        v_res := replace(v_res,')','');
        v_res := replace(v_res,' ','');
        v_res := replace(v_res,'-','');
        v_res := substr(v_res,length(v_res) - 9);
        RETURN '+38'
        || v_res;
    END clr_phone; 
 ---------------------- 

    FUNCTION blob2clob (
        p_blob        IN BLOB,
        p_blob_csid   IN INTEGER DEFAULT dbms_lob.default_csid
    ) RETURN CLOB AS

        l_clob           CLOB;
        l_dest_offset    INTEGER := 1;
        l_src_offset     INTEGER := 1;
        l_lang_context   INTEGER := dbms_lob.default_lang_ctx;
        l_warning        INTEGER;
    BEGIN
        IF
            p_blob IS NULL
        THEN
            RETURN NULL;
        END IF;
        dbms_lob.createtemporary(lob_loc => l_clob,cache => false);
        dbms_lob.converttoclob(dest_lob => l_clob,src_blob => p_blob,amount => dbms_lob.lobmaxsize,dest_offset => l_dest_offset,src_offset => l_src_offset
,blob_csid => p_blob_csid,lang_context => l_lang_context,warning => l_warning);

        RETURN l_clob;
    END blob2clob;  

-- подготовка тела сообщения -- 

    FUNCTION message_body (
        p_chat_id             INT DEFAULT in_chat_id,
        p_message_id          INT DEFAULT in_message_id,
        p_text                IN CLOB,
        p_parse_mode          IN VARCHAR DEFAULT 'HTML',
        p_resize_keyboard     IN BOOLEAN DEFAULT true,
        p_one_time_keyboard   IN BOOLEAN DEFAULT true,
        p_buttons_colum       IN INT DEFAULT 2
    ) RETURN CLOB AS

        v_body   CLOB;
        v_ex1    INT;
        v_ex2    INT;
        CURSOR cur1 IS SELECT
            *
                       FROM
            reply_markup_keyboard;

        CURSOR cur2 IS SELECT
            *
                       FROM
            reply_markup_inline_keyboard;

        v_i      INT;
    BEGIN
        SELECT
            COUNT(*)
        INTO
            v_ex1
        FROM
            reply_markup_keyboard;  
            -- inline keyboard -- 

        SELECT
            COUNT(*)
        INTO
            v_ex2
        FROM
            reply_markup_inline_keyboard;  

     -- отправляем запрос --  

        apex_json.initialize_clob_output;
        apex_json.open_object;
        apex_json.write('chat_id',p_chat_id);
        apex_json.write('message_id',p_message_id);
        apex_json.write('text',p_text);
        apex_json.write('parse_mode',p_parse_mode);
        IF
            v_ex1 != 0 OR v_ex2 != 0
        THEN
            v_i := 0;
            apex_json.open_object('reply_markup');
            apex_json.write('one_time_keyboard',p_one_time_keyboard);
            apex_json.write('resize_keyboard',p_resize_keyboard);
        END IF;

        IF
            v_ex1 != 0
        THEN
            apex_json.open_array('keyboard');
            apex_json.open_array ();
            FOR c1 IN cur1 LOOP
                v_i := v_i + 1;
                apex_json.open_object;
                apex_json.write('text',c1.text);
                apex_json.write('request_contact',1 = c1.request_contact);
                apex_json.close_object;
                IF
                    v_i = p_buttons_colum
                THEN
                    apex_json.close_array;
                    apex_json.open_array;
                    v_i := 0;
                END IF;

            END LOOP;

            apex_json.close_array;
            apex_json.close_array;
        END IF;

        IF
            v_ex2 != 0
        THEN
            v_i := 0;
            apex_json.open_array('inline_keyboard');
            apex_json.open_array ();
            FOR c2 IN cur2 LOOP
                v_i := v_i + 1;
                apex_json.open_object;
                apex_json.write('text',c2.text);
                apex_json.write('callback_data',c2.callback_data);
                apex_json.close_object;
                IF
                    v_i = p_buttons_colum
                THEN
                    apex_json.close_array;
                    apex_json.open_array;
                    v_i := 0;
                END IF;

            END LOOP;

            apex_json.close_array;
            apex_json.close_array;
        END IF;

        IF
            v_ex1 != 0 OR v_ex2 != 0
        THEN
            apex_json.close_object;
        END IF;
        apex_json.close_object;
        v_body := apex_json.get_clob_output;
        RETURN v_body;
    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'message_body',
                v_err_msg
            );

    END message_body; 

--отправка сообщения --  

    PROCEDURE sendmessage (
        p_chat_id             INT DEFAULT in_chat_id,
        p_text                IN CLOB,
        p_parse_mode          IN VARCHAR DEFAULT 'HTML',
        p_resize_keyboard     IN BOOLEAN DEFAULT true,
        p_one_time_keyboard   IN BOOLEAN DEFAULT true,
        p_buttons_colum       IN INT DEFAULT 2
    ) AS
        v_body     CLOB;
        v_result   CLOB;
    BEGIN
        v_body := message_body(p_chat_id,NULL,p_text,p_parse_mode,p_resize_keyboard,p_one_time_keyboard,p_buttons_colum);

        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        v_result := apex_web_service.make_rest_request(p_url => p_url
        || p_token
        || '/sendMessage',p_http_method => 'POST',p_body => v_body);

        apex_json.free_output;
        IF
            p_debug = 1
        THEN
            add_journ(v_body => v_body,v_result => v_result,v_chat_id => p_chat_id,v_metod => 'sendMessage');
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'sendmessage',
                v_err_msg
            );

    END sendmessage;  

     -- редактировать сообщение -- 

    PROCEDURE editmessage (
        p_chat_id             INT DEFAULT in_chat_id,
        p_message_id          INT DEFAULT in_message_id,
        p_text                IN CLOB,
        p_parse_mode          IN VARCHAR DEFAULT 'HTML',
        p_resize_keyboard     IN BOOLEAN DEFAULT true,
        p_one_time_keyboard   IN BOOLEAN DEFAULT true,
        p_buttons_colum       IN INT DEFAULT 2
    ) AS
        v_result   CLOB;
        v_body     CLOB;
    BEGIN
        v_body := message_body(p_chat_id,p_message_id,p_text,p_parse_mode,p_resize_keyboard,p_one_time_keyboard,p_buttons_colum);

        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        v_result := apex_web_service.make_rest_request(p_url => p_url
        || p_token
        || '/editMessageText',p_http_method => 'POST',p_body => v_body);

        apex_json.free_output;
        IF
            p_debug = 1
        THEN
            add_journ(v_body => v_body,v_result => v_result,v_chat_id => p_chat_id,v_metod => 'editMessage');
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'editmessage',
                v_err_msg
            );

    END editmessage;  

     -- настройка webhook для входящих сообщений --  

    PROCEDURE setwebhook (
        p_webhook_url IN VARCHAR
    ) AS
        v_result   CLOB;
        v_body     CLOB;
    BEGIN  
     -- отправляем запрос --  
        apex_json.initialize_clob_output;  
    -- json --  
        apex_json.open_object;
        apex_json.write('url',p_webhook_url
        || '/'
        || p_token);
        apex_json.close_object;
        v_body := apex_json.get_clob_output;
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        v_result := apex_web_service.make_rest_request(p_url => p_url
        || p_token
        || '/setWebhook',p_http_method => 'POST',p_body => v_body);

        apex_json.free_output;
        IF
            p_debug = 1
        THEN
            add_journ(v_body => v_body,v_result => v_result,v_metod => 'setWebhook');
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'setwebhook',
                v_err_msg
            );

    END setwebhook;  

    -- разбор входящего сообщения --  

    PROCEDURE in_parse (
        p_body CLOB
    )
        AS
    BEGIN
        IF
            p_debug = 1
        THEN
            add_journ(v_body => p_body,v_metod => 'in_parse');
        END IF;

        apex_json.parse(p_body); 
        -- проверим callback -- 
        in_data := apex_json.get_varchar2('callback_query.data');
        IF
            in_data IS NOT NULL
        THEN
            in_chat_id := apex_json.get_number(p_path => 'callback_query.message.chat.id');
            in_message_id := apex_json.get_number(p_path => 'callback_query.message.message_id');
            in_text := apex_json.get_varchar2('callback_query.message.text');
        ELSE
            in_chat_id := apex_json.get_number(p_path => 'message.chat.id');
            in_message_id := apex_json.get_number(p_path => 'message.message_id');
            in_text := apex_json.get_varchar2('message.text');
        END IF; 
 -- contact --  

        in_phone_number := clr_phone(apex_json.get_varchar2('message.contact.phone_number') );
        in_first_name := apex_json.get_varchar2('message.contact.first_name');
        in_last_name := apex_json.get_varchar2('message.contact.last_name');  
   ---       
        bot_in_point;
    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'in_parse',
                v_err_msg
            );

    END in_parse;  

-- проверка и регистрация пользователя --  

    PROCEDURE check_user (
        v_ex OUT NUMBER
    )
        AS
    BEGIN  

-- проверка регистрации пользователя  --  
        SELECT
            COUNT(*)
        INTO
            v_ex
        FROM
            bot_users
        WHERE
            chat_id = in_chat_id;

        IF
            v_ex = 0 AND in_phone_number IS NULL
        THEN  
-- пользователь не зарегистрирован, запрос на регистрацию -   
            INSERT INTO reply_markup_keyboard (
                text,
                request_contact
            ) VALUES (
                'Зареєструватись',
                1
            );

            sendmessage(p_text => 'Натисніть кнопку "Зареєструватись" для відправки свого номеру телефону модератору.',p_one_time_keyboard => false
);
        ELSIF v_ex = 0 AND in_phone_number IS NOT NULL THEN  
--  добавим пользователя --  
            INSERT INTO bot_users (
                chat_id,
                first_name,
                last_name,
                phone,
                crt
            ) VALUES (
                in_chat_id,
                in_first_name,
                in_last_name,
                in_phone_number,
                SYSDATE
            );

            bot_main_menu;
            v_ex := 1;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'check_user',
                v_err_msg
            );

    END check_user;  

    -- сброс счетчика сессий --  

    PROCEDURE reset_st (
        p_chat_id IN INT DEFAULT in_chat_id
    )
        AS
    BEGIN
        UPDATE bot_sessions
            SET
                st = 0,
                menu = NULL,
                text = NULL
        WHERE
            chat_id = p_chat_id;

        session_st := 0;
        session_menu := NULL;
    END reset_st;  

    -- запись сесии --   

    PROCEDURE save_session (
        v_menu   IN VARCHAR2 DEFAULT NULL,
        v_st     IN INT DEFAULT 0
    ) AS
        v_ex   INT;
        r_     bot_sessions%rowtype;
    BEGIN
        r_.chat_id := in_chat_id;
        SELECT
            COUNT(*)
        INTO
            v_ex
        FROM
            bot_sessions
        WHERE
            chat_id = r_.chat_id; 

----------------------------------------  
-- запишем значения сесии --------------  

        r_.mdf := SYSDATE;
        r_.text := in_text;
        r_.menu := v_menu;
        r_.st := v_st;
        IF
            v_ex = 0
        THEN
            INSERT INTO bot_sessions VALUES r_;

        ELSE
            UPDATE bot_sessions
                SET
                    row = r_
            WHERE
                chat_id = r_.chat_id;

        END IF;

        session_st := v_st;
        session_menu := v_menu;
    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'save_session',
                v_err_msg
            );

    END save_session; 

--   получение сесии --  

    PROCEDURE get_session AS
        r_   bot_sessions%rowtype;
    BEGIN
        SELECT
            *
        INTO
            r_
        FROM
            bot_sessions
        WHERE
            chat_id = in_chat_id;

        session_st := r_.st;
        session_menu := r_.menu;
    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'get_session',
                v_err_msg
            );

    END get_session; 

-- авторизация пользователя через телеграм -- 

    PROCEDURE auth_pin (
        v_username IN VARCHAR2
    ) AS
        v_pin   VARCHAR2(10);
        r_      bot_users%rowtype;
    BEGIN
        v_pin := round(dbms_random.value(1000,9999),0);
        SELECT
            *
        INTO
            r_
        FROM
            bot_users
        WHERE
            upper(login) = upper(v_username);

        UPDATE bot_users
            SET
                pin = v_pin,
                mdf = SYSDATE
        WHERE
            upper(login) = upper(v_username);

        sendmessage(p_chat_id => r_.chat_id,p_text => v_pin);
    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'auth_pin',
                v_username
                || ': '
                || v_err_msg
            );

    END auth_pin; 

      -- сообщение о входе в приложение -- 

    PROCEDURE auth_reg (
        v_username   IN VARCHAR2,
        v_app_name   IN VARCHAR2
    ) AS
        r_   bot_users%rowtype;
    BEGIN
        SELECT
            *
        INTO
            r_
        FROM
            bot_users
        WHERE
            upper(login) = upper(v_username);

        UPDATE bot_users
            SET
                pin = NULL,
                mdf = SYSDATE
        WHERE
            upper(login) = upper(v_username);

        sendmessage(p_chat_id => r_.chat_id,p_text => 'Вход в приложение '
        || v_app_name
        || ' в '
        || TO_CHAR(SYSDATE,'dd.mm.yyyy hh24:mi:ss') );

    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := sqlerrm;
            INSERT INTO bot_err_journ (
                crt,
                metod,
                err_msg
            ) VALUES (
                SYSDATE,
                'auth_reg',
                v_err_msg
            );

    END auth_reg;

END telegram;
/

CREATE OR REPLACE PROCEDURE  "BOT_MAIN_MENU" 
    AS
BEGIN
    telegram.sendmessage(p_text => ' Вас вітає бот ');

    DELETE FROM reply_markup_keyboard;
    INSERT INTO reply_markup_keyboard ( text ) VALUES ( 'Меню' );
    telegram.sendmessage(p_text => 'Головне меню',p_one_time_keyboard => false);
END bot_main_menu;
/

CREATE OR REPLACE PROCEDURE  "BOT_IN_POINT" AS
    v_ex        INT;
    v_err_msg   CLOB;
BEGIN   
-- проверка и регистрация пользователя --  
    telegram.check_user(v_ex);
    IF
        v_ex = 0
    THEN
        return;
    END IF;  

    -- прочитаем значения сесии --  
    telegram.get_session;
    CASE
        WHEN telegram.in_text = 'Меню' THEN
            telegram.reset_st;
            bot_main_menu;
        ELSE
            telegram.reset_st;
            bot_main_menu;
    END CASE;

EXCEPTION
    WHEN OTHERS THEN
        v_err_msg := sqlerrm;
        INSERT INTO bot_err_journ (
            crt,
            metod,
            err_msg
        ) VALUES (
            SYSDATE,
            'in_point',
            v_err_msg
        );

END bot_in_point;
/


