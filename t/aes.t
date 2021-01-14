# vi:ft=

use Test::Nginx::Socket::Lua;

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

our $HttpConfig = <<'_EOC_';
    lua_package_path 'lib/?.lua;;';
    lua_package_cpath 'lib/?.so;;';
_EOC_

#log_level 'warn';

run_tests();

__DATA__

=== TEST 1: AES default hello
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local aes_default = aes:new("secret")
            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-128 CBC MD5: ", str.to_hex(encrypted))
            local decrypted = aes_default:decrypt(encrypted)
            ngx.say(decrypted == "hello")
        ';
    }
--- request
GET /t
--- response_body
AES-128 CBC MD5: 7b47a4dbb11e2cddb2f3740c9e3a552b
true
--- no_error_log
[error]



=== TEST 2: AES empty key hello
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local aes_default = aes:new("")
            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-128 (empty key) CBC MD5: ", str.to_hex(encrypted))
            local decrypted = aes_default:decrypt(encrypted)
            ngx.say(decrypted == "hello")
        ';
    }
--- request
GET /t
--- response_body
AES-128 (empty key) CBC MD5: 6cb1a35bf9d66e92c9dec684fc329746
true
--- no_error_log
[error]



=== TEST 3: AES 8-byte salt
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local aes_default = aes:new("secret","WhatSalt")
            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-128 (salted) CBC MD5: ", str.to_hex(encrypted))
            local decrypted = aes_default:decrypt(encrypted)
            ngx.say(decrypted == "hello")
        ';
    }
--- request
GET /t
--- response_body
AES-128 (salted) CBC MD5: f72db89f8e19326d8da4928be106705c
true
--- no_error_log
[error]



=== TEST 4: AES oversized or too short salt
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local res, err = aes:new("secret","Oversized!")
            ngx.say(res, ", ", err)
            res, err = aes:new("secret","abc")
            ngx.say(res, ", ", err)
        ';
    }
--- request
GET /t
--- response_body
nil, salt must be 8 characters or nil
nil, salt must be 8 characters or nil
--- no_error_log
[error]



=== TEST 5: AES-256 ECB SHA1 no salt
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local aes_default = aes:new("secret",nil,
              aes.cipher(256,"ecb"),aes.hash.sha1)
            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-256 ECB SHA1: ", str.to_hex(encrypted))
            local decrypted = aes_default:decrypt(encrypted)
            ngx.say(decrypted == "hello")
        ';
    }
--- request
GET /t
--- response_body
AES-256 ECB SHA1: 927148b31f0e89696a222489403f540d
true
--- no_error_log
[error]



=== TEST 6: AES-256 ECB SHA1x5 no salt
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local aes_default = aes:new("secret",nil,
              aes.cipher(256,"ecb"),aes.hash.sha1,5)
            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-256 ECB SHA1: ", str.to_hex(encrypted))
            local decrypted = aes_default:decrypt(encrypted)
            ngx.say(decrypted == "hello")
        ';
    }
--- request
GET /t
--- response_body
AES-256 ECB SHA1: d1a9b6e59b8980e783df223889563bee
true
--- no_error_log
[error]



=== TEST 7: AES-128 CBC custom keygen
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local aes_default = aes:new("Xr4ilOzQ4PCOq3aQ0qbuaQ==",nil,
              aes.cipher(128,"cbc"),
              {iv = ngx.decode_base64("Jq5cyFTja2vfyjZoSN6muw=="),
               method = ngx.decode_base64})
            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-128 CBC (custom keygen) MD5: ", str.to_hex(encrypted))
            local decrypted = aes_default:decrypt(encrypted)
            ngx.say(decrypted == "hello")
            local aes_check = aes:new("secret")
            local encrypted_check = aes_check:encrypt("hello")
            ngx.say(encrypted_check == encrypted)
        ';
    }
--- request
GET /t
--- response_body
AES-128 CBC (custom keygen) MD5: 7b47a4dbb11e2cddb2f3740c9e3a552b
true
true
--- no_error_log
[error]



=== TEST 8: AES-128 CBC custom keygen (without method)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local aes_default = aes:new(ngx.decode_base64("Xr4ilOzQ4PCOq3aQ0qbuaQ=="),nil,
              aes.cipher(128,"cbc"),
              {iv = ngx.decode_base64("Jq5cyFTja2vfyjZoSN6muw==")})
            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-128 CBC (custom keygen) MD5: ", str.to_hex(encrypted))
            local decrypted = aes_default:decrypt(encrypted)
            ngx.say(decrypted == "hello")
            local aes_check = aes:new("secret")
            local encrypted_check = aes_check:encrypt("hello")
            ngx.say(encrypted_check == encrypted)
        ';
    }
--- request
GET /t
--- response_body
AES-128 CBC (custom keygen) MD5: 7b47a4dbb11e2cddb2f3740c9e3a552b
true
true
--- no_error_log
[error]



=== TEST 9: AES-128 CBC custom keygen (without method, bad key len)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"

            local aes_default, err = aes:new("hel", nil, aes.cipher(128,"cbc"),
              {iv = ngx.decode_base64("Jq5cyFTja2vfyjZoSN6muw==")})

            if not aes_default then
                ngx.say("failed to new: ", err)
                return
            end

            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-128 CBC (custom keygen) MD5: ", str.to_hex(encrypted))
            local decrypted = aes_default:decrypt(encrypted)
            ngx.say(decrypted == "hello")
            local aes_check = aes:new("secret")
            local encrypted_check = aes_check:encrypt("hello")
            ngx.say(encrypted_check == encrypted)
        ';
    }
--- request
GET /t
--- response_body
failed to new: bad key length
--- no_error_log
[error]



=== TEST 10: AES-128 CBC custom keygen (without method, bad iv)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"

            local aes_default, err = aes:new(
                ngx.decode_base64("Xr4ilOzQ4PCOq3aQ0qbuaQ=="),
                nil,
                aes.cipher(128,"cbc"),
                {iv = "helloworld&helloworld"}
            )

            if not aes_default then
                ngx.say("failed to new: ", err)
                return
            end

            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-128 CBC (custom keygen) MD5: ", str.to_hex(encrypted))
            local decrypted = aes_default:decrypt(encrypted)
            ngx.say(decrypted == "hello")
            local aes_check = aes:new("secret")
            local encrypted_check = aes_check:encrypt("hello")
            ngx.say(encrypted_check == encrypted)
        ';
    }
--- request
GET /t
--- response_body
failed to new: bad iv length
--- no_error_log
[error]



=== TEST 11: AES-256 GCM sha256 no salt
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local aes_default = aes:new("secret",nil,
              aes.cipher(256,"gcm"), aes.hash.sha256, 1, 12)
            local encrypted = aes_default:encrypt("hello")
            ngx.say("AES-256 GCM: ", str.to_hex(encrypted[1]),
                    " tag: ",  str.to_hex(encrypted[2]))
            local decrypted, err = aes_default:decrypt(encrypted[1], encrypted[2])
            ngx.say(decrypted == "hello")
        ';
    }
--- request
GET /t
--- response_body
AES-256 GCM: 4acef84443 tag: bcecc29fb0d8b5c895e21f6ea89681a2
true
--- no_error_log
[error]



=== TEST 12: AES-256 GCM with iv
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local aes = require "resty.aes"
            local str = require "resty.string"
            local aes_default = aes:new(
                str.from_hex("40A4510F290AD8182AF4B0260C655F8511E5B46BCA20EA191D8BC7B4D99CE95F"),
                nil,
                aes.cipher(256,"gcm"),
                {iv = str.from_hex("f31a8c01e125e4720481be05")})
            local encrypted = aes_default:encrypt("13770713710")
            ngx.say("AES-256 GCM: ", str.to_hex(encrypted[1]),
                    " tag: ",  str.to_hex(encrypted[2]))
            local decrypted, err = aes_default:decrypt(encrypted[1], encrypted[2])
            ngx.say(decrypted == "13770713710")
        ';
    }
--- request
GET /t
--- response_body
AES-256 GCM: 755eccf6aa0cd51d55ad0c tag: 9a61f5a3cc3089bbe7de00a3dd484a1d
true
--- no_error_log
[error]
