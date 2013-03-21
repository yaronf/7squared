7squared: main.vala model.vala view.vala
	valac -g -o 7squared --pkg gtk+-3.0 --pkg clutter-gtk-1.0 --pkg gmodule-2.0 --pkg gee-1.0 main.vala model.vala view.vala

valadoc: main.vala model.vala view.vala
	rm -rf valadoc
	valadoc -o ./valadoc --pkg gtk+-3.0 --pkg clutter-gtk-1.0 --pkg gmodule-2.0 --pkg gee-1.0 --vapidir=/usr/share/vala-0.20/vapi/ *.vala

clean:
	rm 7squared
	rm -r valadoc
