.PHONY: seed seed-drop

seed:
	./import-archive.sh

seed-drop:
	./import-archive.sh --drop
