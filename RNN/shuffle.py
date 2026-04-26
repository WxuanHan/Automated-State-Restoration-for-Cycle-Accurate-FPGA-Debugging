import random

# File paths
input_file = "cordic_input_real.txt"
output_file = "cordic_output_real.txt"

# Read both files
with open(input_file, "r") as f_in, open(output_file, "r") as f_out:
    inputs = [line.strip() for line in f_in.readlines()]
    outputs = [line.strip() for line in f_out.readlines()]

# Ensure both files have the same number of lines
if len(inputs) != len(outputs):
    raise ValueError("Input and output files have different lengths!")

# Combine and shuffle together
paired = list(zip(inputs, outputs))
random.shuffle(paired)

# Split back into separate lists
shuffled_inputs, shuffled_outputs = zip(*paired)

# Write shuffled data to new files
with open("cordic_input_real_shuffled.txt", "w") as f_in, open("cordic_output_real_shuffled.txt", "w") as f_out:
    for inp, out in zip(shuffled_inputs, shuffled_outputs):
        f_in.write(f"{inp}\n")
        f_out.write(f"{out}\n")

print("Shuffling completed. Files saved as:")
print(" - cordic_input_real_shuffled.txt")
print(" - cordic_output_real_shuffled.txt")
