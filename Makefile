7squared: main.vala model.vala view.vala
	valac -g -X -w -o 7squared --pkg gtk+-3.0 --pkg clutter-gtk-1.0 --pkg gmodule-2.0 --pkg gee-1.0 --pkg posix main.vala model.vala view.vala

valadoc: main.vala model.vala view.vala
	rm -rf valadoc
	valadoc --private -o ./valadoc --package-name=seven_squared --pkg gtk+-3.0 --pkg clutter-gtk-1.0 --pkg gmodule-2.0 --pkg gee-1.0 --vapidir=/usr/share/vala-0.20/vapi/ *.vala

clean:
	rm -f 7squared
	rm -rf valadoc
