(* Open image to analyse *)
(* let test_image = import_image "../Poincare_Index/fingerprint.jpg" *)

(* Types *)
type sp = {mutable x : int ; mutable y : int ; mutable typ : int};; (* 0 = loop | 1 = delta | 2 = whorl | 3 = nothing*)

(* Image Convolution - Gaussian filter *)
let (gaussian_kernel : matrix) = [| (* Size = 5 *)
[|0.012841;0.026743;0.03415;0.026743;0.012841|];
[|0.026743;0.055697;0.071122;0.055697;0.026743|];
[|0.03415;0.071122;0.090818;0.071122;0.03415|];
[|0.026743;0.055697;0.071122;0.055697;0.026743|];
[|0.012841;0.026743;0.03415;0.026743;0.012841|];
|];;

(* Do convolution on only one pixel *)
let convolve i j (kernel : matrix) (image_matrix : matrix) r =
	let tmp = ref 0. in
	let (h,w) = ((Array.length image_matrix),(Array.length image_matrix.(0))) in
	for m = 0 to (r - 1) do
		for n = 0 to (r - 1) do
			(* Use zero-padding to extend the image *)
			if not(((i-m) < 0) || ((j-n) < 0) || ((i-m) > (h-1)) || ((j-n) > (w-1))) then 
				tmp := !tmp +.
					(kernel.(m).(n)*.image_matrix.(i - m).(j - n))
		done;
	done;
	!tmp;; (* WARNING: WTF is this -1 *)

(* Convolve whole matrix *)
let convolve_matrix (kernel : matrix) (m: matrix) =
		let r = Array.length kernel in (* Kernel is square *)
		let (h,w) = ((Array.length m),(Array.length m.(0))) in
		let ret = Array.make_matrix h w 0. in
		for i = 0 to (h - 1) do
			for j = 0 to (w - 1) do
				ret.(i).(j) <- (convolve i j kernel m r)
			done;
		done;
		ret;;

(* Apply Gaussian filter on image *)
let applyGaussianFilter (image : bw_image) =
		image.matrix<-(convolve_matrix gaussian_kernel image.matrix);;

(* Get all surrounding blocks *)
let getSurrounding i j image_bw (bloc_size : bloc_size)=
	let ret = Array.make_matrix bloc_size bloc_size 0. in
	for k = 0 to 2 do
		for l = 0 to 2 do
			ret.(k).(l) <- image_bw.matrix.(i + (k - 1)).(j + (l-1));
		done;
	done;(ret : matrix);;

(* Make matrix array for each bloc_size*bloc_size blocs *)
let makeBlocList img (bloc_size : bloc_size) =
		let (h,w) = (img.height,img.width) in
		let ret = Array.make (h*w)
						 ((Array.make_matrix bloc_size bloc_size 0. : matrix)) in
		for i = 1 to (h-2) do
			for j = 1 to (w-2) do
				ret.(i*w+j) <- (getSurrounding i j img bloc_size)
			done;
		done;
		ret;;

(* Uses Sobel operator *)
let pi = 4. *. atan 1.
let hX = [|[|1.;0.;-1.|];[|2.;0.;-2.|];[|1.;0.;-1.|]|];;
let hY = [|[|-1.;-2.;-1.|];[|0.;0.;0.|];[|1.;2.;1.|]|];; (* Transposée de gX *)
let getAngles m height width =
	let gX = convolve_matrix hX m in
	let gY = convolve_matrix hY m in
	let ret = Array.make_matrix height width 0. in
	for i = 0 to (height-1) do
		for j = 0 to (width-1) do
			ret.(i).(j) <- (atan2 gY.(i).(j) gX.(i).(j))
		done;
	done;(ret : matrix);;

(* Sum angles and get the sg type *)
let sumAngles i j (matrix : matrix) =
	let error = (10./.100.)*.pi in (* 15% of error *)
	let sum = ref 0. in
	let ret = {x = i ; y = j ; typ = 4} in
	for k = 0 to 2 do
		for l = 0 to 2 do
			if (k != 1) && (l != 1) then sum := !sum +. matrix.(k).(l)
		done;
	done;
	if (abs_float (!sum -. pi)) < error then ret.typ<-(1)
	else if (abs_float (!sum +. pi)) < error then ret.typ<-(2)
	else if (abs_float (!sum -. 2.*.pi)) < error then ret.typ<-(3);
	ret;;

(* Get coordonates from array position *)
let getCoordonates ind w = ((ind/w),(ind mod w));;

(* Get all the singularity points *)
let poincare_index (image : bw_image) =
	applyGaussianFilter image; (* Apply Gaussian filter *)
	let blocs = makeBlocList image 8 in
	let ret = Array.make_matrix (image.height) (image.width) {x = 0 ; y = 0 ; typ = 4} in
	for i = 0 to ((Array.length blocs) - 1) do
		let (x,y) = getCoordonates i image.width in
		ret.(x).(y) <- sumAngles x y (getAngles blocs.(i) 8 8)
	done;
	ret;;

(* Display singularity points *)
let display_sp image =
	let great_image = (troncateImage image 8) in
	let sps = poincare_index (imageToGreyScale great_image) in
	open_graph (getFormat great_image.width great_image.height);
	draw_image (make_image great_image.matrix) 0 0;
	set_color red;
	for i = 5 to (great_image.height - 5) do
		for j = 5 to (great_image.width - 5) do
				if sps.(i).(j).typ < 4 then
					(moveto j i;
					draw_circle j i 5);
		done;
	done;
	let _ = read_key() in close_graph();;

(* List singularity points *)
let list_sp image =
	let great_image = (troncateImage image 8) in
	let sps = poincare_index (imageToGreyScale great_image) in
	for i = 5+1 to (great_image.height - 5 - 1) do (* 5 = kernel width *)
		for j = 5+1 to (great_image.width - 5 - 1) do
			if sps.(i).(j).typ < 4 then
				begin
					if sps.(i).(j).typ = 0 then print_string "Loop at" (* Loop *)
					else if sps.(i).(j).typ = 1 then print_string "Delta at" (* Delta *)
					else if sps.(i).(j).typ = 2 then print_string "Whorl at"; (* Whorl *)
					print_string (getFormat i j);
					print_string "\n";
				end;
		done;
	done;;

(* Apply a function to each element of a matrix *)
let matrixApply f (matrix : matrix) =
	for i = 0 to ((Array.length matrix) - 1) do
		for j = 0 to ((Array.length matrix.(0)) - 1) do
			matrix.(i).(j) <- f (matrix.(i).(j))
		done;
	done;;

(* Get the whole image orientation field
let imageOrientationField image =
	let bw_img = imageToGreyScale image in
	applyGaussianFilter bw_img; (* Apply Gaussian filter *)
	let orien_matrix = getAngles bw_img.matrix (image.height - 1) (image.width - 1) in
	let rad2deg x = (x *. 180.)/.pi in
	matrixApply rad2deg orien_matrix;
	open_graph (getFormat image.width image.height);
	draw_image (make_image image.matrix) 0 0;
	for i = 0 to (image.height - 1) do
		for j = 0 to (image.width - 1) do
			let f x = (orien_matrix.(i).(j)*.(x +. (float_of_int j)) +. (float_of_int i)) in
			begin
				moveto i j;
				lineto i (f (float_of_int j));
			end
		done;
	done;
	let _ = read_key() in close_graph();; *)
