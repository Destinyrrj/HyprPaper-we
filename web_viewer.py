zimport gi



gi.require_version('Gtk', '4.0')


gi.require_version('WebKit', '6.0')


gi.require_version('Gtk4LayerShell', '1.0')


from gi.repository import Gtk, WebKit, Gtk4LayerShell, Gdk, Gio


import sys


import os





class WebWallpaperWindow(Gtk.ApplicationWindow):


    def __init__(self, *args, **kwargs):


        super().__init__(*args, **kwargs)


        


        self.webview = WebKit.WebView()


        self.set_child(self.webview)


        


        # Configure layer shell for background wallpaper display


        Gtk4LayerShell.init_for_window(self)


        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.BACKGROUND)


        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)


        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)


        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)


        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)


        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)





    def load_uri(self, uri):


        self.webview.load_uri(uri)





class WebWallpaperApp(Gtk.Application):


    def __init__(self, uri, *args, **kwargs):


        super().__init__(*args, application_id="dev.gemini.hyprpaperwe.simple.v2", **kwargs)


        self.uri = uri


        self.win = None





    def do_activate(self):


        if not self.win:


            self.win = WebWallpaperWindow(application=self)


        self.win.load_uri(self.uri)


        self.win.present()





if __name__ == "__main__":


    if len(sys.argv) != 2:


        sys.exit(1)





    uri = Gio.File.new_for_path(sys.argv[1]).get_uri()


    app = WebWallpaperApp(uri)


    app.run(None)

