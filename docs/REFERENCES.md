# References

Every source used by Kairos. Verify each link resolves before the deck.

## Data

- IndPenSim: industrial-scale penicillin fed-batch simulation, http://www.industrialpenicillinsimulation.com/
- Dataset mirror used: Kaggle, Big Data-Biopharmaceutical manufacturing (stephengoldie), https://www.kaggle.com/datasets/stephengoldie/big-databiopharmaceutical-manufacturing (original: Mendeley Data, DOI 10.17632/pdnjz7zz5x, CC BY 4.0)
- Goldrick, S. et al. (2015). The development of an industrial-scale fed-batch fermentation simulation. Journal of Biotechnology 193, 70-82. https://doi.org/10.1016/j.jbiotec.2014.10.029
- Goldrick, S. et al. (2019). Modern day monitoring and control challenges outlined on an industrial-scale benchmark fermentation process. Computers & Chemical Engineering 130. https://doi.org/10.1016/j.compchemeng.2019.05.037

## Science and methods

- van't Riet, K. (1979). Review of measuring methods and results in nonviscous gas-liquid mass transfer in stirred vessels. Ind. Eng. Chem. Process Des. Dev. 18(3), 357-364. https://doi.org/10.1021/i260071a001
- Nomikos, P. & MacGregor, J.F. (1994). Monitoring batch processes using multiway principal component analysis. AIChE Journal 40(8). https://doi.org/10.1002/aic.690400809
- Lundberg, S.M. & Lee, S.-I. (2017). A unified approach to interpreting model predictions. NeurIPS. https://arxiv.org/abs/1705.07874
- Romano, Y., Patterson, E. & Candès, E. (2019). Conformalized quantile regression. NeurIPS. https://arxiv.org/abs/1905.03222
- Bajpai, R.K. & Reuss, M. (1980). A mechanistic model for penicillin production. J. Chem. Technol. Biotechnol. 30. https://doi.org/10.1002/jctb.503300108

## Alternative-protein process library (backend/app/processes/catalog.yaml)

### Mycoprotein
- Moore et al., 21st Century Guidebook to Fungi, 17.18 The Quorn fermentation: https://davidmoore.org.uk/21st_century_guidebook_to_fungi_platinum/Ch17_18.htm
- Microbiology Society: Mycoprotein production and food sustainability: https://microbiologysociety.org/resource/mycoprotein-production-and-food-sustainability.html
- Wiebe, Quorn mycoprotein, Mycologist 18 (2004): https://davidmoore.org.uk/assets/fungi4schools/Reprints/Mycologist_articles/Post-16/Foods/V18pp017-020_Quorn.pdf

### Yeast protein
- Green Queen: Revyve raises funding for yeast protein (S. cerevisiae, primary grown yeast): https://www.greenqueen.com.hk/?p=81864
- Baker's yeast fed-batch: pH 4.8 and RQ 0.9-1.0 control (Biotechnol Appl Biochem 66:3): https://www.infona.pl/resource/bwmeta1.element.wiley-bab-v-66-i-3-bab1735
- Dabros et al. 2018, Crabtree control in fed-batch yeast: https://arodes.hes-so.ch/record/2614/files/Dabros_2018_Crabtree_Ctrl.pdf

### Microalgae protein
- Nutrition Insight: Brevel 'illuminated fermentation' chlorella: https://www.nutritioninsight.com/news/brevel-chlorella-nutraceuticals-microalgae-supplements.html
- FoodIngredientsFirst: Brevel opens commercial microalgae protein plant: https://www.foodingredientsfirst.com/news/brevel-targets-plant-based-food-with-new-commercial-plant-for-microalgae-protein-supply.html
- High-density Chlorella culture grown in fermenters (36 °C, glucose fed-batch): https://asep.lib.cas.cz/arl-cav/cs/detail-cav_un_epca-0388567-Production-of-highdensity-Chlorella-culture-grown-in-fermenters/
- Heterotrophic Chlorella sorokiniana protein production (30 °C, pH 6.5): https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2021.774854/pdf
- Microalgae protein setpoint (temp_c): https://asep.lib.cas.cz/arl-cav/cs/detail-cav_un_epca-0388567-Production-of-highdensity-Chlorella-culture-grown-in-fermenters/ (36 °C); https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2021.774854/pdf (30 °C)

### Solein (gas fermentation)
- Solar Foods: 100-fold scale-up at Factory 01 (20,000 L, 0.8 g/L/h): https://solarfoods.com/?p=20611
- Solar Foods press release PDF: https://solarfoods.com/wp-content/uploads/2025/05/Press-release-Solar-Foods-confirms-successful-100-fold-industrial-scaling-of-Soleins-production-technology.pdf
- EU novel food application summary: Xanthobacter sp. SoF1, continuous bioprocess: https://food.ec.europa.eu/system/files/2023-08/novel-food_sum_ongoing-app_2021-1730.pdf
- Pander et al., hydrogen-oxidizing bacteria for food and feed protein: https://pmc.ncbi.nlm.nih.gov/articles/PMC9996702

### Fermentation-derived whey protein
- FDA response letter, GRN 000863 (beta-lactoglobulin from T. reesei): https://fda.gov/media/136751/download
- FoodNavigator: Perfect Day no-questions letter for non-animal whey: https://www.foodnavigator.com/Article/2020/04/14/Perfect-Day-secures-no-objections-letter-from-FDA-for-non-animal-whey-protein/

### Lactoferrin
- FDA response letter, GRN 001219 (rbLf from K. phaffii M020, fed-batch, secreted): https://www.fda.gov/media/187845/download
- Thermo Fisher (Invitrogen) Pichia fermentation process guidelines: https://assets.thermofisher.com/TFS-Assets/LSG/manuals/pichiaferm_prot.pdf
- Vegconomist: TurtleTree first FDA clearance for precision-fermented lactoferrin: https://vegconomist.com/ingredients/turtletree-becomes-first-receive-fda-clearance-precision-fermented-lactoferrin/
- Lactoferrin setpoint (temp_c): https://assets.thermofisher.com/TFS-Assets/LSG/manuals/pichiaferm_prot.pdf (30 °C set point, avoid >32 °C; 28 °C lower bound assumed)
- Lactoferrin setpoint (do_pct): https://assets.thermofisher.com/TFS-Assets/LSG/manuals/pichiaferm_prot.pdf (DO >20%; upper bound assumed)

### Animal-free collagen
- FDA response letter, GRN 001171 (collagen polypeptide from E. coli K-12 S9188, secreted): https://www.fda.gov/media/186898/download
- FoodNavigator-USA: FDA no-questions letter for Geltor collagen: https://foodnavigator-usa.com/Article/2025/10/16/fda-greenlights-in-demand-vegan-collagen-from-geltor/
- Johnston et al. 2002, acetate-threshold control of E. coli fed-batch: https://link.springer.com/article/10.1007/s00449-002-0287-8

### Bioalbumen (ovalbumin)
- FDA response letter, GRN 001249 (ovalbumin from T. reesei TR112): https://www.fda.gov/media/188998/download
- FoodNavigator: FDA greenlights Onego Bio egg white protein: https://www.foodnavigator.com/Article/2025/09/24/fda-greenlights-onego-bios-bio-identical-egg-white-protein-gras-dossier/
- THE EVERY Company GRAS notice cover letter (egg white protein from K. phaffii): https://fda.gov/media/170789/download

## Tools and models

- Anthropic Claude via Amazon Bedrock: us.anthropic.claude-sonnet-5 (chat), us.anthropic.claude-haiku-4-5-20251001-v1:0 (alarm cards); https://aws.amazon.com/bedrock/
- LightGBM https://lightgbm.readthedocs.io · scikit-learn https://scikit-learn.org · SHAP https://shap.readthedocs.io · NumPy/pandas/SciPy
- FastAPI https://fastapi.tiangolo.com · React https://react.dev · three.js https://threejs.org · React Three Fiber https://r3f.docs.pmnd.rs · Tailwind CSS https://tailwindcss.com · Radix UI https://www.radix-ui.com · d3-geo https://d3js.org/d3-geo · Natural Earth via world-atlas https://github.com/topojson/world-atlas
- Flutter https://flutter.dev · Riverpod https://riverpod.dev
- Fonts: Inter, JetBrains Mono, Space Grotesk (SIL OFL) via google/fonts https://github.com/google/fonts
- AWS: EC2, S3, CloudFront, IAM (us-east-1)
- Claude Code (used for development) https://claude.com/claude-code
