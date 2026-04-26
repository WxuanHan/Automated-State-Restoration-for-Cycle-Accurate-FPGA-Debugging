The RNN code includes data preparation, training, and validation.

The sampled sequences are located in the cordic_series folder. Verify the generated images and summarize them in the result folder.

The RNN is trained using the training_field_sqrt.py script, with the trained model being rnn_xy_shuffle.keras.

The validation_field.py script is then used for validation.

Format_Convertor_for_RNN.py converts data exported from the DUT into floating-point format for easier observation and computation (if the DUT is in Q format).

Two anomaly injectors generate sequences containing anomalies: one for isolated anomalies and another for mixed anomalies. These sequences include a binary error mask and ownership code, with adjustable anomaly proportions. (Generated sequences reside in the cordic_series folder.)

The shuffle.py randomizes sequence order to prevent the RNN from learning temporal dependencies.
