/**
 * @license This file is part of anycook. The new internet cookbook
 * Copyright (C) 2013 Jan Graßegger
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see [http://www.gnu.org/licenses/].
 * 
 * @author Jan Graßegger <jan@anycook.de>
 */
'use strict';
(function( $ , globals){
	globals.AnycookAPI = {
		_settings : function(settings){
			if(settings){
				$(document).data('AnycookAPI', settings);
			}
			else{
				return $(document).data('AnycookAPI');
			}
		},
		_get : function(api, data, callback, error){
			api = api || '';
			data = data || {};
			callback = callback || function(){};
			
			var settings = AnycookAPI._settings();
			error = error || settings.error;

			$.extend(data, {appId : settings.appId});
			return $.ajax({
			    url : settings.baseUrl+api,
			    type : 'GET',
			    dataType : 'json',
			    data : data,
			    xhrFields : {
					withCredentials: true
				},
			    success : callback,
			    error : error
			});
		},
		_post : function(api, data, callback, error){
			api = api || '';
			data = data || {};
			callback = callback || function(){};
			
			var settings = AnycookAPI._settings();
			$.extend(data, {appId : settings.appId});

			error = error || settings.error;


			return $.ajax({
			    url: settings.baseUrl+api,
			    type: 'POST',
			    data:data,
			    dataType:'json',
			    contentType: 'application/x-www-form-urlencoded',
			    xhrFields:{
					withCredentials: true
				},
			    success: callback,
			    error: error
			});
		},
		_postJSON : function(api, data, callback, error){
			api = api || '';
			data = data || {};
			callback = callback || function(){};

			var settings = AnycookAPI._settings();
			error = error || settings.error;

			return $.ajax({
			    url: settings.baseUrl+api+'?appId='+settings.appId,
			    type: 'POST',
			    data:JSON.stringify(data),
			    dataType:'json',
			    contentType: 'application/json; charset=utf-8',
			    xhrFields:{
					withCredentials: true
				},
			    success: callback,
			    error: error
			});
		},
		_put : function(api,data, callback, error){
			api = api || '';
			data = data || {};
			callback = callback || function(){};

			var settings = AnycookAPI._settings();
			error = error || settings.error;

			var url = settings.baseUrl+api;
			$.extend(data, {appId : settings.appId});
			
			return $.ajax({
			    url: url,
			    type: 'PUT',
			    data:data,
			    contentType: 'application/x-www-form-urlencoded',
			    xhrFields:{
					withCredentials: true
				},
			    success: callback,
				error: error
			});
		},
		_putJSON : function(api, data, callback, error){
			api = api || '';
			data = data || {};
			callback = callback || function(){};

			var settings = AnycookAPI._settings();
			error = error || settings.error;

			return $.ajax({
			    url: settings.baseUrl+api+'?appId='+settings.appId,
			    type: 'PUT',
			    data:JSON.stringify(data),
			    dataType : 'json',
			    contentType: 'application/json; charset=utf-8',
			    xhrFields:{
					withCredentials: true
				},
			    success: callback,
			    error: error
			});
		},
		_delete : function(api,data, callback, error){
			api = api || '';
			data = data || {};
			callback = callback || function(){};
			
			var settings = AnycookAPI._settings();
			error = error || settings.error;

			$.extend(data, {appId : settings.appId});
			return $.ajax({
			    url: settings.baseUrl+api,
			    type: 'DELETE',
			    data:data,
			    xhrFields:{
	                withCredentials: true
				},
			    success: callback,
			    error : error
			});
		},
		init : function(options){
			var dfd = $.Deferred();
			var settings = {
				appId: -1,
				baseUrl: 'http://api.anycook.de',
				scripts: [
					'autocomplete',
					'category',
					'discover',
					'discussion',
					'ingredient',
					'life',
					'message',
					'registration',
					'recipe',
					'search',
					'setting',
					'session',
					'tag',
					'user'
				],
				error : function(xhr){
					console.error(xhr);
				}
			};
			
			if(options){
				$.extend(settings, options);
			}
			
			AnycookAPI._settings(settings);
			
			var numScripts = settings.scripts.length;
			var numLoaded = 0;

			var checkLoaded = function(){
				numLoaded++;
				if(numLoaded === numScripts){
					dfd.resolve();
				}
			};

			for(var i in settings.scripts){
				var script = settings.scripts[i];
				$.getScript(settings.baseUrl+'/js/anycookapi.'+script+'.js', checkLoaded);
			}
				
			return dfd.promise();
		}
	};
})( jQuery, this);