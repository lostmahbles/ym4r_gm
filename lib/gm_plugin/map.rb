module Ym4r
  module GmPlugin 
    #Representing the Google Maps API class GMap2.
    class GMap
      include MappingObject
      
      #A constant containing the declaration of the VML namespace, necessary to display polylines under IE.
      VML_NAMESPACE = "xmlns:v=\"urn:schemas-microsoft-com:vml\""
      
      #The id of the DIV that will contain the map in the HTML page. 
      attr_reader :container
      
      #By default the map in the HTML page will be globally accessible with the name +map+.
      def initialize(container, variable = "map")
        @container = container
        @variable = variable
        @init = []
        @init_end = [] #for stuff that must be initialized at the end (controls)
        @init_begin = [] #for stuff that must be initialized at the beginning (center + zoom)
        @global_init = []
      end

      #Deprecated. Use the static version instead.
      def header(with_vml = true)
        GMap.header(:with_vml => with_vml)
      end

      #Outputs the header necessary to use the Google Maps API, by including the JS files of the API, as well as a file containing YM4R/GM helper functions. By default, it also outputs a style declaration for VML elements. This default can be overriddent by passing <tt>:with_vml => false</tt> as option to the method. You can also pass a <tt>:host</tt> option in order to select the correct API key for the location where your app is currently running, in case the current environment has multiple possible keys. Usually, in this case, you should pass it <tt>@request.host</tt>. If you have defined only one API key for the current environment, the <tt>:host</tt> option is ignored. Finally you can override all the key settings in the configuration by passing a value to the <tt>:key</tt> key.
      def self.header(options = {})
        options[:with_vml] = true unless options.has_key?(:with_vml)
        if options.has_key?(:key)
          api_key = options[:key]
        elsif GMAPS_API_KEY.is_a?(Hash)
          #For this environment, multiple hosts are possible.
          #:host must have been passed as option
          if options.has_key?(:host)
            api_key = GMAPS_API_KEY[options[:host]]
          else
            raise AmbiguousGMapsAPIKeyException.new(GMAPS_API_KEY.keys.join(","))
          end
        else
          #Only one possible key: take it
          api_key = GMAPS_API_KEY
        end
        a = "<script src=\"http://maps.google.com/maps?file=api&v=2&key=#{api_key}\" type=\"text/javascript\"></script>\n"
        a << "<script src=\"/javascripts/ym4r-gm.js\" type=\"text/javascript\"></script>\n"
        a << "<style type=\"text/css\">\n v\:* { behavior:url(#default#VML);}\n</style>" if options[:with_vml]
        a
      end
     
      #Outputs the <div id=...></div> which has been configured to contain the map. You can pass <tt>:width</tt> and <tt>:height</tt> as options to output this in the style attribute of the DIV element (you could also achieve the same effect by putting the dimension info into a CSS or using the instance method GMap#header_width_height)
      def div(options = {})
        attributes = "id=\"#{@container}\" "
        if options.has_key?(:height) && options.has_key?(:width)
          attributes += "style=\"width:#{options[:width]};height:#{options[:height]}\""
        end
        "<div #{attributes}></div>"
      end

      #Outputs a style declaration setting the dimensions of the DIV container of the map. This info can also be set manually in a CSS.
      def header_width_height(width,height)
        "<style type=\"text/css\">\n##{@container} { height: #{height}px;\n  width: #{width}px;\n}\n</style>"
      end

      #Records arbitrary JavaScript code and outputs it during initialization inside the +load+ function.
      def record_init(code)
        @init << code
      end

      #Initializes the controls: you can pass a hash with keys <tt>:small_map</tt>, <tt>:large_map</tt>, <tt>:small_zoom</tt>, <tt>:scale</tt>, <tt>:map_type</tt> and <tt>:overview_map</tt> and a boolean value as the value (usually true, since the control is not displayed by default)
      def control_init(controls = {})
        @init_end << add_control(GSmallMapControl.new) if controls[:small_map]
        @init_end << add_control(GLargeMapControl.new) if controls[:large_map]
        @init_end << add_control(GSmallZoomControl.new) if controls[:small_zoom]
        @init_end << add_control(GScaleControl.new) if controls[:scale]
        @init_end << add_control(GMapTypeControl.new) if controls[:map_type]
        @init_end << add_control(GOverviewMapControl.new) if controls[:overview_map]
      end

      #Initializes the initial center and zoom of the map. +center+ can be both a GLatLng object or a 2-float array.
      def center_zoom_init(center, zoom)
        if center.is_a?(GLatLng)
          @init_begin << set_center(center,zoom)
        else
          @init_begin << set_center(GLatLng.new(center),zoom)
        end
      end

      #Initializes the map by adding an overlay (marker or polyline).
      def overlay_init(overlay)
        @init << add_overlay(overlay)
      end

      #Sets up a new map type. If +add+ is false, all the other map types of the map are wiped out. If you want to access the map type in other methods, you should declare the map type first (with +declare_init+).
      def add_map_type_init(map_type, add = true)
        unless add
          @init << get_map_types.set_property(:length,0)
        end
        @init << add_map_type(map_type)
      end
      #for legacy purpose
      alias :map_type_init :add_map_type_init

      #Sets the map type displayed by default after the map is loaded. It should be known from the map (ie either the default map types or a user-defined map type added with <tt>add_map_type_init</tt>). Use <tt>set_map_type_init(GMapType::G_SATELLITE_MAP)</tt> or <tt>set_map_type_init(GMapType::G_HYBRID_MAP)</tt> to initialize the map with repsecitvely the Satellite view and the hybrid view.
      def set_map_type_init(map_type)
        @init << set_map_type(map_type)
      end

      #Locally declare a MappingObject with variable name "name"
      def declare_init(variable, name)
        @init << variable.declare(name)
      end

      #Records arbitrary JavaScript code and outputs it during initialization outside the +load+ function (ie globally).
      def record_global_init(code)
        @global_init << code
      end
      
      #Deprecated. Use icon_global_init instead.
      def icon_init(icon , name)
        icon_global_init(icon , name)
      end
      
      #Initializes an icon  and makes it globally accessible through the JavaScript variable of name +variable+.
      def icon_global_init(icon , name)
        declare_global_init(icon,name)
      end
      
      #Declares the overlay globally with name +name+
      def overlay_global_init(overlay,name)
        declare_global_init(overlay,name)
        @init << add_overlay(overlay)
      end

      #Globally declare a MappingObject with variable name "name"
      def declare_global_init(variable,name)
        @global_init << variable.declare(name)
      end
      
      #Outputs the initialization code for the map. By default, it outputs the script tags, performs the initialization in response to the onload event of the window and makes the map globally available.
      def to_html(options = {})
        no_load = options[:no_load]
        no_script_tag = options[:no_script_tag]
        no_declare = options[:no_declare]
        no_global = options[:no_global]
        
        html = ""
        html << "<script type=\"text/javascript\">\n" if !no_script_tag
        #put the functions in a separate javascript file to be included in the page
        html << @global_init * "\n"
        html << "var #{@variable};\n" if !no_declare and !no_global
        html << "window.onload = addCodeToFunction(window.onload,function() {\nif (GBrowserIsCompatible()) {\n" if !no_load
        if !no_declare and no_global 
          html << "#{declare(@variable)}\n"
        else
          html << "#{assign_to(@variable)}\n"
        end
        html << @init_begin * "\n"
        html << @init * "\n"
        html << @init_end * "\n"
        html << "\n}\n});\n" if !no_load
        html << "</script>" if !no_script_tag
        html
      end
      
      #Outputs in JavaScript the creation of a GMap2 object 
      def create
        "new GMap2(document.getElementById(\"#{@container}\"))"
      end
    end

    class AmbiguousGMapsAPIKeyException < StandardError
    end

  end
end

