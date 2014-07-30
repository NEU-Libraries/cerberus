(function (factory) {
	var timer;
	var addAsync = function(){
		if(!window.asyncWebshims){
			if(!window.asyncWebshims){
				window.asyncWebshims = {
					cfg: [],
					ready: []
				};
			}
		}
	};
	var start = function(){
		if(window.jQuery){
			factory(jQuery);
			factory = jQuery.noop;
			clearInterval(timer);
		}
		if (typeof define === 'function' && define.amd && define.amd.jQuery) {
			define('polyfiller', ['jquery'], factory);
			clearInterval(timer);
		}
		
	};
	var timer = setInterval(start, 1);
	
	window.webshims = {
		setOptions: function(){
			addAsync();
			window.asyncWebshims.cfg.push(arguments);
		},
		ready: function(){
			addAsync();
			window.asyncWebshims.ready.push(arguments);
		},
		activeLang: function(lang){
			addAsync();
			window.asyncWebshims.lang = lang;
		},
		polyfill: function(features){
			addAsync();
			window.asyncWebshims.polyfill = features;
		}
	};
	window.webshim = window.webshims;
	
	start();
}(function($){
	"use strict";
	if (typeof WSDEBUG === 'undefined') {
		window.WSDEBUG = true;
	}
	var DOMSUPPORT = 'dom-support';
	var jScripts = $(document.scripts || 'script');
	var special = $.event.special;
	var emptyJ = $([]);
	var Modernizr = window.Modernizr;
	var asyncWebshims = window.asyncWebshims;
	var addTest = Modernizr.addTest;
	var Object = window.Object;
	var html5 = window.html5 || {};
	var firstRun;
	var webshims = window.webshims;
	var addSource = function(text){
		return text +"\n//# sourceURL="+this.url;
	};
	Modernizr.advancedObjectProperties = Modernizr.objectAccessor = Modernizr.ES5 = !!('create' in Object && 'seal' in Object);
	
	if(Modernizr.ES5 && !('toJSON' in Date.prototype)){
		Modernizr.ES5 = false;
	}
	
	
	$.extend(webshims, {
		version: '1.12.0',
		cfg: {
			
			//addCacheBuster: false,
			waitReady: true,
//			extendNative: false,
			loadStyles: true,
			disableShivMethods: true,
			wspopover: {appendTo: 'auto', hideOnBlur: true},
			ajax: {},
			loadScript: function(src, success, fail){
				$.ajax($.extend({}, webCFG.ajax, {url: src, success: success, dataType: 'script', cache: true, global: false, dataFilter: addSource}));
			},
			
			basePath: (function(){
				var script = jScripts.filter('[src*="polyfiller.js"]');
				var path;
				script = script[0] || script.end()[script.end().length - 1];
				if(WSDEBUG && document.currentScript && script !=  document.currentScript && document.currentScript.src){
					webshims.warn("It seems you need to set webshims.setOptions('basePath', 'pathTo/shims/'); manually.");
				}
				path = ( ( !('hrefNormalized' in $.support) || $.support.hrefNormalized  ) ? script.src : script.getAttribute("src", 4) ).split('?')[0];
				path = path.slice(0, path.lastIndexOf("/") + 1) + 'shims/';
				return path;
			})()
		},
		bugs: {},
		/*
		 * some data
		 */
		modules: {},
		features: {},
		featureList: [],
		setOptions: function(name, opts){
			if (typeof name == 'string' && opts !== undefined) {
				webCFG[name] = (!$.isPlainObject(opts)) ? opts : $.extend(true, webCFG[name] || {}, opts);
			} else if (typeof name == 'object') {
				$.extend(true, webCFG, name);
			}
		},
		addPolyfill: function(name, cfg){
			cfg = cfg || {};
			var feature = cfg.f || name;
			if (!webshimsFeatures[feature]) {
				webshimsFeatures[feature] = [];
				webshims.featureList.push(feature);
				webCFG[feature] = {};
			}
			
			if(!webshimsFeatures[feature].failedM && cfg.nM){
				$.each(cfg.nM.split(' '), function(i, name){
					if(!(name in Modernizr)){
						webshimsFeatures[feature].failedM = name;
						return false;
					}
				});
			}
			
			if(webshimsFeatures[feature].failedM){
				cfg.test = WSDEBUG ? function(){
					webshims.error('webshims needs Modernizr.'+webshimsFeatures[feature].failedM + ' to implement feature: '+ feature);
					return true;
				} : true;
			}
			webshimsFeatures[feature].push(name);
			cfg.options = $.extend(webCFG[feature], cfg.options);
			
			addModule(name, cfg);
			if (cfg.methodNames) {
				$.each(cfg.methodNames, function(i, methodName){
					webshims.addMethodName(methodName);
				});
			}
		},
		polyfill: (function(){
			var loaded = {};
			return function(features){
				if(!features){
					features = webshims.featureList;
					WSDEBUG && webshims.warn('loading all features without specifing might be bad for performance');
				}
					
				if (typeof features == 'string') {
					features = features.split(' ');
				}
				
				if(WSDEBUG){
					for(var i = 0; i < features.length; i++){
						if(loaded[features[i]]){
							webshims.error(features[i] +' already loaded, you might want to use updatePolyfill instead? see: bit.ly/12BtXX3');
						}
						loaded[features[i]] = true;
					}
				}
				return webshims._polyfill(features);
			};
		})(),
		_polyfill: function(features){
			var toLoadFeatures = [];
			
			firstRun();
			
			if($.inArray('forms', features) == -1 && $.inArray('forms-ext', features) !== -1){
				features.push('forms');
				if(WSDEBUG){
					webshims.error('need to load forms feature to use forms-ext feature.');
				}
			}
			
			if (webCFG.waitReady) {
				$.readyWait++;
				onReady(features, function(){
					$.ready(true);
				});
			}
			
			$.each(features, function(i, feature){
				if(!webshimsFeatures[feature]){
					WSDEBUG && webshims.error("could not find webshims-feature (aborted): "+ feature);
					isReady(feature, true);
					return;
				}
				if (feature !== webshimsFeatures[feature][0]) {
					onReady(webshimsFeatures[feature], function(){
						isReady(feature, true);
					});
				}
				toLoadFeatures = toLoadFeatures.concat(webshimsFeatures[feature]);
			});
			if(webCFG.loadStyles){
				loader.loadCSS('styles/shim.css');
			}
			loadList(toLoadFeatures);
			
		},
		
		/*
		 * handle ready modules
		 */
		reTest: (function(){
			var resList;
			var reTest = function(i, name){
				var module = modules[name];
				var readyName = name+'Ready';
				var feature;
				if(module && !module.loaded && !( (module.test && $.isFunction(module.test) ) ? module.test([]) : module.test )){
					if(special[readyName]){
						delete special[readyName];
					}
					feature = webshimsFeatures[module.f];
					
					resList.push(name);
				}
			};
			return function(moduleNames){
				if(typeof moduleNames == 'string'){
					moduleNames = moduleNames.split(' ');
				}
				resList = [];
				$.each(moduleNames, reTest);
				loadList(resList);
			};
		})(),
		isReady: function(name, _set){
			
			name = name + 'Ready';
			if (_set) {
				if (special[name] && special[name].add) {
					return true;
				}
				
				special[name] = $.extend(special[name] || {}, {
					add: function(details){
						details.handler.call(this, name);
					}
				});
				$(document).triggerHandler(name);
			}
			return !!(special[name] && special[name].add) || false;
		},
		ready: function(events, fn /*, _created*/){
			var _created = arguments[2];
			var evt = events;
			if (typeof events == 'string') {
				events = events.split(' ');
			}
			
			if (!_created) {
				events = $.map($.grep(events, function(evt){
					return !isReady(evt);
				}), function(evt){
					return evt + 'Ready';
				});
			}
			if (!events.length) {
				fn($, webshims, window, document);
				return;
			}
			var readyEv = events.shift(), readyFn = function(){
				onReady(events, fn, true);
			};
			
			$(document).one(readyEv, readyFn);
		},
		
		/*
		 * basic DOM-/jQuery-Helpers
		 */
		
		
		capturingEvents: function(names, _maybePrevented){
			if (!document.addEventListener) {
				return;
			}
			if (typeof names == 'string') {
				names = [names];
			}
			$.each(names, function(i, name){
				var handler = function(e){
					e = $.event.fix(e);
					if (_maybePrevented && webshims.capturingEventPrevented) {
						webshims.capturingEventPrevented(e);
					}
					return $.event.dispatch.call(this, e);
				};
				special[name] = special[name] || {};
				if (special[name].setup || special[name].teardown) {
					return;
				}
				$.extend(special[name], {
					setup: function(){
						this.addEventListener(name, handler, true);
					},
					teardown: function(){
						this.removeEventListener(name, handler, true);
					}
				});
			});
		},
		register: function(name, fn){
			var module = modules[name];
			if (!module) {
				webshims.error("can't find module: " + name);
				return;
			}
			module.loaded = true;
			var ready = function(){
				fn($, webshims, window, document, undefined, module.options);
				isReady(name, true);
			};
			if (module.d && module.d.length) {
				onReady(module.d, ready);
			} else {
				ready();
			}
			
		},
		c: {},
		/*
		 * loader
		 */
		loader: {
		
			addModule: function(name, ext){
				modules[name] = ext;
				ext.name = ext.name || name;
				if(!ext.c){
					ext.c = [];
				}
				$.each(ext.c, function(i, comboname){
					if(!webshims.c[comboname]){
						webshims.c[comboname] = [];
					}
					webshims.c[comboname].push(name);
				});
			},
			loadList: (function(){
			
				var loadedModules = [];
				var loadScript = function(src, names){
					if (typeof names == 'string') {
						names = [names];
					}
					$.merge(loadedModules, names);
					loader.loadScript(src, false, names);
				};
				
				var noNeedToLoad = function(name, list){
					if (isReady(name) || $.inArray(name, loadedModules) != -1) {
						return true;
					}
					var module = modules[name];
					var cfg = webCFG[module.f || name] || {};
					var supported;
					if (module) {
						supported = (module.test && $.isFunction(module.test)) ? module.test(list) : module.test;
						if (supported) {
							isReady(name, true);
							return true;
						} else {
							return false;
						}
					}
					return true;
				};
				
				var setDependencies = function(module, list){
					if (module.d && module.d.length) {
						var addDependency = function(i, dependency){
							if (!noNeedToLoad(dependency, list) && $.inArray(dependency, list) == -1) {
								list.push(dependency);
							}
						};
						$.each(module.d, function(i, dependency){
							if (modules[dependency]) {
								if(!modules[dependency].loaded){
									addDependency(i, dependency);
								}
							}
							else 
								if (webshimsFeatures[dependency]) {
									$.each(webshimsFeatures[dependency], addDependency);
									onReady(webshimsFeatures[dependency], function(){
										isReady(dependency, true);
									});
								}
						});
						if (!module.noAutoCallback) {
							module.noAutoCallback = true;
						}
					}
				};
				
				return function(list, combo){
					var module;
					var loadCombos = [];
					var i;
					var len;
					var foundCombo;
					var loadCombo = function(j, combo){
						foundCombo = combo;
						$.each(webshims.c[combo], function(i, moduleName){
							if($.inArray(moduleName, loadCombos) == -1 || $.inArray(moduleName, loadedModules) != -1){
								foundCombo = false;
								return false;
							}
						});
						if(foundCombo){
							loadScript('combos/'+foundCombo, webshims.c[foundCombo]);
							return false;
						}
					};
					
					//length of list is dynamically
					for (i = 0; i < list.length; i++) {
						module = modules[list[i]];
						if (!module || noNeedToLoad(module.name, list)) {
							if (WSDEBUG && !module) {
								webshims.warn('could not find: ' + list[i]);
							}
							continue;
						}
						if (module.css && webCFG.loadStyles) {
							loader.loadCSS(module.css);
						}
						
						if (module.loadInit) {
							module.loadInit();
						}
						
						
						setDependencies(module, list);
						if(!module.loaded){
							loadCombos.push(module.name);
						}
						module.loaded = true;
					}
					
					for(i = 0, len = loadCombos.length; i < len; i++){
						foundCombo = false;
						
						module = loadCombos[i];
						
						if($.inArray(module, loadedModules) == -1){
							if(webCFG.debug != 'noCombo'){
								$.each(modules[module].c, loadCombo);
							}
							if(!foundCombo){
								loadScript(modules[module].src || module, module);
							}
						}
					}
				};
			})(),
			
			makePath: function(src){
				if (src.indexOf('//') != -1 || src.indexOf('/') === 0) {
					return src;
				}
				
				if (src.indexOf('.') == -1) {
					src += '.js';
				}
				if (webCFG.addCacheBuster) {
					src += webCFG.addCacheBuster;
				}
				return webCFG.basePath + src;
			},
			
			loadCSS: (function(){
				var parent, loadedSrcs = {};
				return function(src){
					src = this.makePath(src);
					if (loadedSrcs[src]) {
						return;
					}
					parent = parent || $('link, style')[0] || $('script')[0];
					loadedSrcs[src] = 1;
					$('<link rel="stylesheet" />').insertBefore(parent).attr({
						href: src
					});
				};
			})(),
			
			loadScript: (function(){
				var loadedSrcs = {};
				var scriptLoader;
				return function(src, callback, name){
				
					src = loader.makePath(src);
					if (loadedSrcs[src]) {return;}
					var complete = function(){
						
						if (callback) {
							callback();
						}
						
						if (name) {
							if (typeof name == 'string') {
								name = name.split(' ');
							}
							$.each(name, function(i, name){
								if (!modules[name]) {
									return;
								}
								if (modules[name].afterLoad) {
									modules[name].afterLoad();
								}
								isReady(!modules[name].noAutoCallback ? name : name + 'FileLoaded', true);
							});
							
						}
					};
					
					loadedSrcs[src] = 1;
					webCFG.loadScript(src, complete, $.noop);
				};
			})()
		}
	});
	
	/*
	 * shortcuts
	 */
	$.webshims = webshims;
	
	var webCFG = webshims.cfg;
	var webshimsFeatures = webshims.features;
	var isReady = webshims.isReady;
	var onReady = webshims.ready;
	var addPolyfill = webshims.addPolyfill;
	var modules = webshims.modules;
	var loader = webshims.loader;
	var loadList = loader.loadList;
	var addModule = loader.addModule;
	var bugs = webshims.bugs;
	var removeCombos = [];
	var importantLogs = {
		warn: 1,
		error: 1
	};
	
	if(webCFG.debug || (!('crossDomain' in webCFG.ajax) && location.protocol.indexOf('http'))){
		webCFG.ajax.crossDomain = true;
	}
	
	webshims.addMethodName = function(name){
		name = name.split(':');
		var prop = name[1];
		if (name.length == 1) {
			prop = name[0];
			name = name[0];
		} else {
			name = name[0];
		}
		
		$.fn[name] = function(){
			return this.callProp(prop, arguments);
		};
	};
	$.fn.callProp = function(prop, args){
		var ret;
		if(!args){
			args = []; 
		}
		this.each(function(){
			var fn = $.prop(this, prop);
			
			if (fn && fn.apply) {
				ret = fn.apply(this, args);
				if (ret !== undefined) {
					return false;
				}
			} else {
				webshims.warn(prop+ " is not a method of "+ this);
			}
		});
		return (ret !== undefined) ? ret : this;
	};
	
	

	webshims.activeLang = (function(){
		var curLang = navigator.browserLanguage || navigator.language || '';
		onReady('webshimLocalization', function(){
			webshims.activeLang(curLang);
			
		});
		return function(lang){
			if(lang){
				if (typeof lang == 'string' ) {
					curLang = lang;
				} else if(typeof lang == 'object'){
					var args = arguments;
					var that = this;
					onReady('webshimLocalization', function(){
						webshims.activeLang.apply(that, args);
					});
				}
			}
			return curLang;
		};
	})();
	
	webshims.errorLog = [];
	$.each(['log', 'error', 'warn', 'info'], function(i, fn){
		webshims[fn] = function(message){
			if( (importantLogs[fn] && webCFG.debug !== false) || webCFG.debug){
				webshims.errorLog.push(message);
				if(window.console && console.log){
					console[(console[fn]) ? fn : 'log'](message);
				}
			}
		};
	});
	
	/*
	 * jQuery-plugins for triggering dom updates can be also very usefull in conjunction with non-HTML5 DOM-Changes (AJAX)
	 * Example:
	 * $.webshims.addReady(function(context, insertedElement){
	 * 		$('div.tabs', context).add(insertedElement.filter('div.tabs')).tabs();
	 * });
	 * 
	 * $.ajax({
	 * 		success: function(html){
	 * 			$('#main').htmlPolyfill(html);
	 * 		}
	 * });
	 */
	
	(function(){
		
		//Overwrite DOM-Ready and implement a new ready-method
		$.isDOMReady = $.isReady;
		var onReady = function(){
			$.isDOMReady = true;
			isReady('DOM', true);
			setTimeout(function(){
				isReady('WINDOWLOAD', true);
			}, 9999);
		};
		
		firstRun = function(){
			if(!firstRun.run){
				if($.mobile && ($.mobile.textinput || $.mobile.rangeslider || $.mobile.button)){
					if(WSDEBUG){
						webshims.warn('jQM textinput/rangeslider/button detected waitReady was set to false. Use webshims.ready("featurename") to script against polyfilled methods/properties');
					}
					if(!webCFG.readyEvt){
						webCFG.readyEvt = 'pageinit';
					}
					webCFG.waitReady = false;
				}
				
				if (WSDEBUG && webCFG.waitReady && $.isReady) {
					webshims.warn('Call webshims.polyfill before DOM-Ready or set waitReady to false.');
				}
				
				if(!$.isDOMReady && webCFG.waitReady){
					var $Ready = $.ready;
					$.ready = function(unwait){
						if(unwait !== true && document.body){
							onReady();
							$.ready = $Ready;
						}
						return $Ready.apply(this, arguments);
					};
					$.ready.promise = $Ready.promise;
				}
				if(webCFG.readyEvt){
					$(document).one(webCFG.readyEvt, onReady);
				} else {
					$(onReady);
				}
			}
			firstRun.run = true;
		};
		
		setTimeout(function(){
			$(onReady);
		}, 4);
		$(window).on('load', function(){
			onReady();
			setTimeout(function(){
				isReady('WINDOWLOAD', true);
			}, 9);
		});
		
		var readyFns = [];
		var eachTrigger = function(){
			if(this.nodeType == 1){
				webshims.triggerDomUpdate(this);
			}
		};
		$.extend(webshims, {
			addReady: function(fn){
				var readyFn = function(context, elem){
					webshims.ready('DOM', function(){fn(context, elem);});
				};
				readyFns.push(readyFn);
				readyFn(document, emptyJ);
			},
			triggerDomUpdate: function(context){
				if(!context || !context.nodeType){
					if(context && context.jquery){
						context.each(function(){
							webshims.triggerDomUpdate(this);
						});
					}
					return;
				}
				var type = context.nodeType;
				if(type != 1 && type != 9){return;}
				var elem = (context !== document) ? $(context) : emptyJ;
				$.each(readyFns, function(i, fn){
					fn(context, elem);
				});
			}
		});
		
		$.fn.htmlPolyfill = function(a){
			var ret = $.fn.html.call(this,  a);
			if(ret === this && $.isDOMReady){
				this.each(eachTrigger);
			}
			return ret;
		};
		
		$.fn.jProp = function(){
			return this.pushStack($($.fn.prop.apply(this, arguments) || []));
		};
		
		$.each(['after', 'before', 'append', 'prepend', 'replaceWith'], function(i, name){
			$.fn[name+'Polyfill'] = function(a){
				a = $(a);
				$.fn[name].call(this, a);
				if($.isDOMReady){
					a.each(eachTrigger);
				}
				return this;
			};
			
		});
		
		$.each(['insertAfter', 'insertBefore', 'appendTo', 'prependTo', 'replaceAll'], function(i, name){
			$.fn[name.replace(/[A-Z]/, function(c){return "Polyfill"+c;})] = function(){
				$.fn[name].apply(this, arguments);
				if($.isDOMReady){
					webshims.triggerDomUpdate(this);
				}
				return this;
			};
		});
		
		$.fn.updatePolyfill = function(){
			if($.isDOMReady){
				webshims.triggerDomUpdate(this);
			}
			return this;
		};
		
		$.each(['getNativeElement', 'getShadowElement', 'getShadowFocusElement'], function(i, name){
			$.fn[name] = function(){
				return this.pushStack(this);
			};
		});
		
	})();
	
	
	if(WSDEBUG){
		webCFG.debug = true;
	}
	
	//this might be extended by ES5 shim feature
	(function(){
		var defineProperty = 'defineProperty';
		var has = Object.prototype.hasOwnProperty;
		var descProps = ['configurable', 'enumerable', 'writable'];
		var extendUndefined = function(prop){
			for(var i = 0; i < 3; i++){
				if(prop[descProps[i]] === undefined && (descProps[i] !== 'writable' || prop.value !== undefined)){
					prop[descProps[i]] = true;
				}
			}
		};
		var extendProps = function(props){
			if(props){
				for(var i in props){
					if(has.call(props, i)){
						extendUndefined(props[i]);
					}
				}
			}
		};
		if(Object.create){
			webshims.objectCreate = function(proto, props, opts){
				extendProps(props);
				var o = Object.create(proto, props);
				if(opts){
					o.options = $.extend(true, {}, o.options  || {}, opts);
					opts = o.options;
				}
				if(o._create && $.isFunction(o._create)){
					o._create(opts);
				}
				return o;
			};
		}
		if(Object[defineProperty]){
			webshims[defineProperty] = function(obj, prop, desc){
				extendUndefined(desc);
				return Object[defineProperty](obj, prop, desc);
			};
		}
		if(Object.defineProperties){
			webshims.defineProperties = function(obj, props){
				extendProps(props);
				return Object.defineProperties(obj, props);
			};
		}
		webshims.getOwnPropertyDescriptor = Object.getOwnPropertyDescriptor;
		
		webshims.getPrototypeOf = Object.getPrototypeOf;
	})();
	
	

	
	/*
	 * Start Features 
	 */
	
	/* general modules */
	/* change path $.webshims.modules[moduleName].src */
	
	
	addModule('swfmini', {
		test: function(){
			if(window.swfobject && !window.swfmini){
				window.swfmini = window.swfobject;
			}
			return ('swfmini' in window);
		},
		c: [16, 7, 2, 8, 1, 12, 19, 25, 23, 27]
	});
	modules.swfmini.test();
	
	addModule('sizzle', {test: $.expr.filters});
	addModule('$ajax', {test: $.ajax});
	/* 
	 * polyfill-Modules 
	 */
	
	// webshims lib uses a of http://github.com/kriskowal/es5-shim/ to implement
	addPolyfill('es5', {
		test: !!(Modernizr.ES5 && Function.prototype.bind),
		c: [18, 19, 25, 20, 32]
	});
	
	addPolyfill('dom-extend', {
		f: DOMSUPPORT,
		noAutoCallback: true,
		d: ['es5'],
		c: [16, 7, 2, 15, 30, 3, 8, 4, 9, 10, 25, 19, 20, 26, 31]
	});
	
	
	//<geolocation
	
	addPolyfill('geolocation', {
		test: Modernizr.geolocation,
		options: {
			destroyWrite: true
//			,confirmText: ''
		},
		d: ['json-storage'],
		c: [21],
		nM: 'geolocation'
	});
	//>
	
	//<canvas
	(function(){
		addPolyfill('canvas', {
			src: 'excanvas',
			test: Modernizr.canvas,
			options: {type: 'flash'}, //excanvas | flash | flashpro
			noAutoCallback: true,
			
			loadInit: function(){
				var type = this.options.type;
				if(type && type.indexOf('flash') !== -1 && (!modules.swfmini.test() || swfmini.hasFlashPlayerVersion('9.0.0'))){
					this.src = type == 'flash' ? 'FlashCanvas/flashcanvas' : 'FlashCanvasPro/flashcanvas';
				}
			},
			methodNames: ['getContext'],
			d: [DOMSUPPORT],
			nM: 'canvas'
		});
	})();
	//>
	
	
	//<forms
	(function(){
		var formExtend, formOptions, formExtras;
		var fShim = 'form-shim-extend';
		var modernizrInputAttrs = Modernizr.input;
		var modernizrInputTypes = Modernizr.inputtypes;
		var formvalidation = 'formvalidation';
		var fNuAPI = 'form-number-date-api';
		var bustedValidity = false;
		var bustedWidgetUi = false;
		
		var initialFormTest = function(){
			var range, tmp, fieldset;
			if(!initialFormTest.run){
				fieldset = $('<fieldset><textarea required="" /></fieldset>')[0];
				addTest(formvalidation, !!(modernizrInputAttrs.required && modernizrInputAttrs.pattern));
				
				addTest('fieldsetelements', (tmp = 'elements' in fieldset));
				
				if(('disabled' in fieldset)){
					if(!tmp) {
						try {
							if($('textarea', fieldset).is(':invalid')){
								fieldset.disabled = true;
								tmp = $('textarea', fieldset).is(':valid');
							}
						} catch(er){}
					}
					addTest('fieldsetdisabled', tmp);
				}
				if(modernizrInputTypes && modernizrInputTypes.range && !window.opera){
					range = $('<input type="range" style="-webkit-appearance: slider-horizontal; -moz-appearance: range;" />').appendTo('html');
					tmp = range.css('appearance');
					range.remove();
					
					addTest('csstrackrange', tmp == null || tmp == 'range');
					
					addTest('cssrangeinput', tmp == 'slider-horizontal' || tmp == 'range');
					
					addTest('styleableinputrange', Modernizr.csstrackrange || Modernizr.cssrangeinput);
				}
				
				if(Modernizr[formvalidation]){
					bustedWidgetUi = !Modernizr.fieldsetdisabled ||!Modernizr.fieldsetelements || !('value' in document.createElement('progress')) || !('value' in document.createElement('output'));
					bugs.bustedValidity = bustedValidity = window.opera || bustedWidgetUi || !modernizrInputAttrs.list;
				}

				formExtend = Modernizr[formvalidation] && !bustedValidity ? 'form-native-extend' : fShim;
				
			}
			initialFormTest.run = true;
			return false;
		};
		
		if(modernizrInputAttrs && modernizrInputTypes){
			initialFormTest();
		}
		document.createElement('datalist');
				
		
		webshims.validationMessages = webshims.validityMessages = {
			langSrc: 'i18n/formcfg-', 
			availableLangs: ['ar', 'cs', 'el', 'es', 'fr', 'he', 'hi', 'hu', 'it', 'ja', 'lt', 'nl', 'pl', 'pt', 'pt-BR', 'pt-PT', 'ru', 'sv', 'zh-CN']
		};
		webshims.formcfg = $.extend({}, webshims.validationMessages);
		
		webshims.inputTypes = {};
				
		addPolyfill('form-core', {
			f: 'forms',
			d: ['es5'],
			test: initialFormTest,
			options: {
				placeholderType: 'value',
				messagePopover: {},
				list: {
					popover: {
						constrainWidth: true
					}
				},
				iVal: {
					sel: '.ws-validate',
					handleBubble: 'hide',
					recheckDelay: 400
//					,fx: 'slide'
				}
	//			,customMessages: false,
	//			overridePlaceholder: false, // might be good for IE10
	//			replaceValidationUI: false
			},
			methodNames: ['setCustomValidity','checkValidity', 'setSelectionRange'],
			c: [16, 7, 2, 8, 1, 15, 30, 3, 31],
			nM: 'input'
		});
		
		formOptions = webCFG.forms;
				
		addPolyfill('form-native-extend', {
			f: 'forms',
			test: function(toLoad){
				return !Modernizr[formvalidation] || bustedValidity  || $.inArray(fNuAPI, toLoad  || []) == -1 || modules[fNuAPI].test();
			},
			d: ['form-core', DOMSUPPORT, 'form-message'],
			c: [6, 5, 14, 29]
		});
		
		addPolyfill(fShim, {
			f: 'forms',
			test: function(){
				return Modernizr[formvalidation] && !bustedValidity;
			},
			d: ['form-core', DOMSUPPORT, 'sizzle'],
			c: [16, 15, 24, 28]
		});
		
		addPolyfill(fShim+'2', {
			f: 'forms',
			test: function(){
				return Modernizr[formvalidation] && !bustedWidgetUi;
			},
			d: [fShim],
			c: [24]
		});
		
		addPolyfill('form-message', {
			f: 'forms',
			test: function(toLoad){
				return !( formOptions.customMessages || !Modernizr[formvalidation] || bustedValidity || !modules[formExtend].test(toLoad) );
			},
			d: [DOMSUPPORT],
			c: [16, 7, 15, 30, 3, 8, 4, 14, 28]
		});
		
		formExtras = {
			noAutoCallback: true,
			options: formOptions
		};
		addModule('form-validation', $.extend({d: ['form-message', 'form-core']}, formExtras));
		
		addModule('form-validators', $.extend({}, formExtras));
				
		addPolyfill(fNuAPI, {
			f: 'forms-ext',
			options: {
				types: 'date time range number'
			},
			test: function(){
				var ret = true;
				var o = this.options;
				if(!o._types){
					o._types = o.types.split(' ');
				}
				
				initialFormTest();
				$.each(o._types, function(i, name){
					if((name in modernizrInputTypes) && !modernizrInputTypes[name]){
						ret = false;
						return false;
					}
				});
				
				return ret;
			},
			methodNames: ['stepUp', 'stepDown'],
			d: ['forms', DOMSUPPORT],
			c: [6, 5, 18, 17, 14, 28, 29, 32, 33],
			nM: 'input inputtypes'
		});
		
		addModule('range-ui', {
			options: {},
			noAutoCallback: true,
			test: function(){
				return !!$.fn.rangeUI;
			},
			d: ['es5'],
			c: [6, 5, 9, 10, 18, 17, 11]
		});
		
		addPolyfill('form-number-date-ui', {
			f: 'forms-ext',
			test: function(){
				var o = this.options;
				initialFormTest();
				if(o.replaceUI){
					$('html').addClass('ws-replaceui');
				}
				//input widgets on old androids can't be trusted
				if(bustedWidgetUi && !o.replaceUI && (/Android/i).test(navigator.userAgent)){
					o.replaceUI = true;
				}
				return !o.replaceUI && modules[fNuAPI].test();
			},
			d: ['forms', DOMSUPPORT, fNuAPI, 'range-ui'],
			css: 'styles/forms-ext.css',
			options: {
				widgets: {
					calculateWidth: true,
					animate: true
				}
	//			,replaceUI: false
			},
			c: [6, 5, 9, 10, 18, 17, 11]
		});
		
		addPolyfill('form-datalist', {
			f: 'forms',
			test: function(){
				initialFormTest();
				return modernizrInputAttrs.list && !formOptions.fD;
			},
			d: ['form-core', DOMSUPPORT],
			c: [16, 7, 6, 2, 9, 15, 30, 31, 28, 32, 33]
		});
	})();
	//>
	
	//<filereader
	addPolyfill('filereader', {
		test: 'FileReader' in window,
		d: ['swfmini', DOMSUPPORT],
		c: [25, 26, 27]
//		,nM: 'filereader'
	});
	//>
	
	//<details
	if(!('details' in Modernizr)){
		addTest('details', function(){
			return ('open' in document.createElement('details'));
		});
	}
	addPolyfill('details', {
		test: Modernizr.details,
		d: [DOMSUPPORT],
		options: {
//			animate: false,
			text: 'Details'
		},
		c: [21, 22]
	});
	//>
	
	//<mediaelement
	(function(){
		webshims.mediaelement = {};
		
		addPolyfill('mediaelement-core', {
			f: 'mediaelement',
			noAutoCallback: true,
			options: {
				preferFlash: false,
				vars: {},
				params: {},
				attrs: {},
				changeSWF: $.noop
			},
			methodNames: ['play', 'pause', 'canPlayType', 'mediaLoad:load'],
			d: ['swfmini'],
			c: [16, 7, 2, 8, 1, 12, 13, 19, 25, 20, 23],
			nM: 'audio video texttrackapi'
		});
		
		
		addPolyfill('mediaelement-jaris', {
			f: 'mediaelement',
			d: ['mediaelement-core', 'swfmini', DOMSUPPORT],
			test: function(){
				if(!Modernizr.audio || !Modernizr.video || webshims.mediaelement.loadSwf){
					return false;
				}
				
				var options = this.options;
				if(options.preferFlash && !modules.swfmini.test()){
					options.preferFlash = false;
				}
				return !( options.preferFlash && swfmini.hasFlashPlayerVersion('9.0.115') );
			},
			c: [21, 19, 25, 20]
		});
		
		bugs.track = !Modernizr.texttrackapi;
		
		addPolyfill('track', {
			options: {
				positionDisplay: true,
				override: bugs.track
			},
			test: function(){
				return !this.options.override && !bugs.track;
			},
			d: ['mediaelement', DOMSUPPORT],
			methodNames: ['addTextTrack'],
			c: [21, 12, 13, 22],
			nM: 'texttrackapi'
		});
		
		
		addModule('track-ui', {
			d: ['track', DOMSUPPORT]
		});
		
	})();
	//>
	
	
	//>removeCombos<
	addPolyfill('feature-dummy', {
		test: true,
		loaded: true,
		c: removeCombos
	});
	
	webshims.$ = $;
	webshims.M = Modernizr;
	window.webshims = webshims;
	
	jScripts
		.filter('[data-polyfill-cfg]')
		.each(function(){
			try {
				webshims.setOptions( $(this).data('polyfillCfg') );
			} catch(e){
				webshims.warn('error parsing polyfill cfg: '+e);
			}
		})
		.end()
		.filter('[data-polyfill]')
		.each(function(){
			webshims.polyfill( $.trim( $(this).data('polyfill') || '' ) );
		})
	;
	if(asyncWebshims){
		if(asyncWebshims.cfg){
			if(!asyncWebshims.cfg.length){
				asyncWebshims.cfg = [asyncWebshims.cfg];
			}
			$.each(asyncWebshims.cfg, function(i, cfg){
				webshims.setOptions.call(webshims, cfg);
			});
		}
		if(asyncWebshims.ready){
			$.each(asyncWebshims.ready, function(i, ready){
				webshims.ready.apply(webshims, ready);
			});
		}
		if(asyncWebshims.lang){
			webshims.activeLang(asyncWebshims.lang);
		}
		if('polyfill' in asyncWebshims){
			webshims.polyfill(asyncWebshims.polyfill);
		}
	}
	webshims.isReady('jquery', true);
	return webshims;
}));
