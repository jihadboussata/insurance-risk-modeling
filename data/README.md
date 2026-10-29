# Source data and data contract

Download the public **Dataset of an actual motor vehicle insurance portfolio**, version 2, from https://doi.org/10.17632/5cxyb5fp4f.2 (Mendeley Data; Josep Lledó and Jose M. Pavía; CC BY 4.0). Use the 105,555-row, 30-column general portfolio file, not the separate claim-type supplement. Read the companion paper at https://doi.org/10.1007/s13385-024-00398-0 for the codebook and limitations.

The analyzed course copy is `Motor_vehicle_insurance_data.csv`: semicolon-separated, decimal point, DD/MM/YYYY. Put it in `data/raw/` or pass its path with `--data`. If the download is supplied in spreadsheet form, export that general portfolio sheet with these conventions and preserve the column names. Exported bytes can have a different checksum; record that transformation.

Analyzed course-copy SHA-256: `00061a64e355a7f9bbd06f1bcd3f0846b1f849955119a812acf2bc7781ee293a`.

The pipeline needs ID, Date_last_renewal, Date_birth, Date_driving_licence, Year_matriculation, N_claims_year, Cost_claims_year, Power, Area, Second_driver, Type_risk, Distribution_channel and Type_fuel. The full source copy has 30 columns and 53,502 policy–product IDs. IDs repeat over years; a row is not a different independent customer.

N_claims_year is the current-period count; Cost_claims_year is current-period aggregate cost. Vehicle value is recorded at 31/12/2019 and is not a prospective model feature. Raw records are git-ignored. Results contain only aggregate summaries; this repository does not relicense the dataset under MIT.
