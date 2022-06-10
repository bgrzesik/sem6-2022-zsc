import pynq

def main():
    o = pynq.Overlay("design_axi_zybo.bit")
    print("Flashed")

if __name__ == "__main__":
    main()
